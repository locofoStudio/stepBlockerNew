import { useState, useEffect, useCallback, useRef } from 'react';
import { NativeModules, AppState, NativeEventEmitter, Platform, Alert } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

// AsyncStorage keys
const ONBOARDING_KEY = 'HAS_COMPLETED_ONBOARDING';
const BLOCKED_APPS_COUNT_KEY = 'BLOCKED_APPS_COUNT';
const ACTIVE_MODE_KEY = 'ACTIVE_MODE';
const LEVEL_KEY = 'LEVEL';
const LAST_DAY_KEY = 'LAST_DAY';

export type Level = 'easy' | 'medium' | 'hard';

const LEVEL_CONFIG: Record<Level, number> = {
  easy: 20,
  medium: 10,
  hard: 5,
};

export const useStepBlocker = () => {
  // Core state
  const [currentSteps, setCurrentSteps] = useState(0);
  const [blockedAppsCount, setBlockedAppsCount] = useState(0);
  // Initialize to false instead of null - this prevents infinite loading screen
  // Will be updated to true if onboarding is actually completed
  const [isOnboarded, setIsOnboarded] = useState<boolean>(false);
  // #region agent log
  // Log state changes
  useEffect(() => {
    console.log('[useStepBlocker] isOnboarded state changed to:', isOnboarded);
    fetch('http://127.0.0.1:7242/ingest/edb0e970-1aa7-464e-a807-8c4ce69bd913',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'useStepBlocker.ts:30',message:'isOnboarded state changed',data:{isOnboarded:isOnboarded},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'F'})}).catch(()=>{});
  }, [isOnboarded]);
  // #endregion
  const [activeMode, setActiveMode] = useState<'earn' | null>(null);
  const [level, setLevelState] = useState<Level>('easy');
  const [walletBalance, setWalletBalance] = useState(0);
  const [unlockSessionEndTime, setUnlockSessionEndTime] = useState<number | null>(null);
  const [unlockSessionDuration, setUnlockSessionDuration] = useState(0);
  const [timeUntilReset, setTimeUntilReset] = useState(0);
  const [screenDailyAverageSeconds, setScreenDailyAverageSeconds] = useState(0);
  const [isAuthorized, setIsAuthorized] = useState(false);

  // Track steps used for earning
  const stepsUsedForEarningRef = useRef(0);

  // Get native modules (lazy access for bridgeless mode)
  // CRITICAL: Add extensive null checks to prevent EXC_BAD_ACCESS
  const getModules = useCallback(() => {
    // CRITICAL: Don't access NativeModules until React Native is ready
    // This prevents EXC_BAD_ACCESS crashes in bridgeless mode
    if (!modulesReady) {
      return {
        HealthKitModule: null,
        WidgetBridgeModule: null,
        BlockerModule: null,
        ScreenTimeModule: null,
      };
    }
    
    try {
      // Defensive check: ensure NativeModules exists
      if (!NativeModules) {
        console.log('[useStepBlocker] ⚠️ NativeModules is null/undefined');
        return {
          HealthKitModule: null,
          WidgetBridgeModule: null,
          BlockerModule: null,
          ScreenTimeModule: null,
        };
      }
      
      const modules = NativeModules as any;
      
      // Defensive check: ensure modules object is valid
      if (!modules || typeof modules !== 'object') {
        console.log('[useStepBlocker] ⚠️ NativeModules is not a valid object');
        return {
          HealthKitModule: null,
          WidgetBridgeModule: null,
          BlockerModule: null,
          ScreenTimeModule: null,
        };
      }
      
      // Safely access module properties with null checks
      const result = {
        HealthKitModule: modules.HealthKitModule || null,
        WidgetBridgeModule: modules.WidgetBridgeModule || null,
        BlockerModule: modules.BlockerModule || null,
        ScreenTimeModule: modules.ScreenTimeModule || null,
      };
      
      // Log module availability (only once per session to reduce noise)
      if (result.HealthKitModule || result.BlockerModule || result.ScreenTimeModule) {
        console.log('[useStepBlocker] ✅ Native modules available:', {
          HealthKitModule: !!result.HealthKitModule,
          BlockerModule: !!result.BlockerModule,
          ScreenTimeModule: !!result.ScreenTimeModule,
        });
      }
      
      return result;
    } catch (e) {
      console.error('[useStepBlocker] ❌ Error accessing NativeModules:', e);
      return {
        HealthKitModule: null,
        WidgetBridgeModule: null,
        BlockerModule: null,
        ScreenTimeModule: null,
      };
    }
  }, [modulesReady]);

  // Track if native modules are safe to access (delay for bridgeless mode)
  const [modulesReady, setModulesReady] = useState(false);
  
  // Initialize - COMPLETELY REMOVED AsyncStorage from init
  // Only check AsyncStorage when user completes onboarding
  // This keeps the UI fully responsive - NO BLOCKING OPERATIONS
  // CRITICAL: Delay native module access to prevent EXC_BAD_ACCESS in bridgeless mode
  useEffect(() => {
    // Simple delay-based readiness - don't check modules during init to avoid crashes
    // The defensive checks in getModules will handle safety
    const timer = setTimeout(() => {
      console.log('[useStepBlocker] Native modules should be ready now (delay-based)');
      setModulesReady(true);
    }, 500); // 500ms delay to let React Native finish initialization
    
    console.log('[useStepBlocker] Initialization complete - UI should be responsive');
    return () => clearTimeout(timer);
  }, []);

  // Check authorization status when onboarded (after modules are ready)
  useEffect(() => {
    if (!isOnboarded || !modulesReady) return;
    
    const checkAuth = async () => {
      try {
        const modules = NativeModules as any;
        const HealthKitModule = modules?.HealthKitModule;
        
        if (!HealthKitModule) {
          console.log('[useStepBlocker] Cannot check auth: HealthKitModule not available');
          return;
        }
        
        // Check if already authorized
        const authorized = await HealthKitModule.checkAuthorizationStatus();
        if (authorized) {
          console.log('[useStepBlocker] HealthKit already authorized, setting isAuthorized to true');
          setIsAuthorized(true);
        } else {
          console.log('[useStepBlocker] HealthKit not authorized, requesting permissions...');
          // Try to request permissions silently
          await HealthKitModule.requestPermissions();
          const newAuthStatus = await HealthKitModule.checkAuthorizationStatus();
          if (newAuthStatus) {
            setIsAuthorized(true);
          }
        }
      } catch (e) {
        console.error('[useStepBlocker] Auth check failed:', e);
      }
    };
    
    checkAuth();
  }, [isOnboarded, modulesReady]);

  // Sync: Get steps, calculate earned minutes, add to wallet
  const sync = useCallback(async () => {
    try {
      // Direct access to NativeModules - bypass modulesReady check
      const modules = NativeModules as any;
      const HealthKitModule = modules?.HealthKitModule;
      const BlockerModule = modules?.BlockerModule;
      
      if (!HealthKitModule || !BlockerModule) {
        console.log('[useStepBlocker] sync: Modules not available, skipping');
        return;
      }
      
      if (!isAuthorized) return;
      
      const steps = await HealthKitModule.getTodaySteps();
      setCurrentSteps(steps);
      
      if (activeMode !== 'earn') {
        BlockerModule.toggleBlocking(false);
        return;
      }
      
      // Calculate earned minutes (increments of 1000 steps)
      const minutesPer1000 = LEVEL_CONFIG[level];
      const currentIncrements = Math.floor(steps / 1000);
      const usedIncrements = Math.floor(stepsUsedForEarningRef.current / 1000);
      const newIncrements = currentIncrements - usedIncrements;
      
      if (newIncrements > 0) {
        const newMinutes = newIncrements * minutesPer1000;
        
        if (BlockerModule.addToWalletBalance) {
          const result = await BlockerModule.addToWalletBalance(newMinutes);
          setWalletBalance(result.balance || 0);
          stepsUsedForEarningRef.current = currentIncrements * 1000;
        }
      }
      
      // Block/unblock based on session
      const hasActiveSession = unlockSessionEndTime && unlockSessionEndTime > Date.now();
      BlockerModule.toggleBlocking(!hasActiveSession);
    } catch (e) {
      console.error('[useStepBlocker] Sync failed:', e);
    }
  }, [isAuthorized, activeMode, level, walletBalance, unlockSessionEndTime, timeUntilReset, screenDailyAverageSeconds]);

  // Time until midnight
  useEffect(() => {
    const update = () => {
      const now = new Date();
      const midnight = new Date(now);
      midnight.setHours(24, 0, 0, 0);
      setTimeUntilReset(Math.max(0, Math.floor((midnight.getTime() - now.getTime()) / 1000)));
    };
    update();
    const interval = setInterval(update, 1000);
    return () => clearInterval(interval);
  }, []);

  // HealthKit observer
  useEffect(() => {
    if (!isAuthorized) return;
    
    // Direct access to NativeModules - bypass modulesReady check
    const modules = NativeModules as any;
    const HealthKitModule = modules?.HealthKitModule;
    
    if (!HealthKitModule) {
      console.log('[useStepBlocker] HealthKit observer: Module not available');
      return;
    }
    
    const eventEmitter = new NativeEventEmitter(HealthKitModule);
    const subscription = eventEmitter.addListener('StepUpdate', (event) => {
      if (event?.steps !== undefined) {
        setCurrentSteps(event.steps);
        if (activeMode === 'earn') {
          sync();
        }
      }
    });
    
    if (HealthKitModule.startStepObserver) {
      HealthKitModule.startStepObserver();
    }
    
    return () => {
      if (HealthKitModule.stopStepObserver) {
        HealthKitModule.stopStepObserver();
      }
      subscription.remove();
    };
  }, [isAuthorized, activeMode, sync]);

  // Sync on app state change
  useEffect(() => {
    if (isAuthorized) {
      sync();
      const subscription = AppState.addEventListener('change', (nextState) => {
        if (nextState === 'active') sync();
      });
      return () => subscription.remove();
    }
  }, [isAuthorized, sync]);

  // Sync wallet periodically
  const syncWalletBalance = useCallback(async () => {
    try {
      // Direct access to NativeModules - bypass modulesReady check
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule?.getWalletBalance) {
        console.log('[useStepBlocker] syncWalletBalance: Module not available');
        return;
      }
      
      const walletData = await BlockerModule.getWalletBalance();
      setWalletBalance(walletData.balance || 0);
      if (walletData.hasActiveSession && walletData.sessionEndTime) {
        const endTime = walletData.sessionEndTime * 1000;
        if (Date.now() >= endTime) {
          BlockerModule.toggleBlocking(true);
          setUnlockSessionEndTime(null);
          setUnlockSessionDuration(0);
        } else {
          setUnlockSessionEndTime(endTime);
          setUnlockSessionDuration(walletData.sessionDuration || 0);
        }
      } else {
        setUnlockSessionEndTime(null);
        setUnlockSessionDuration(0);
      }
    } catch (e) {
      console.error('[useStepBlocker] Wallet sync failed:', e);
    }
  }, []);

  // Public functions
  const requestHealthAuth = async (): Promise<boolean> => {
    try {
      // Direct access during authorization - bypass modulesReady check
      // This ensures iOS permission dialogs appear immediately
      const modules = NativeModules as any;
      const HealthKitModule = modules?.HealthKitModule;
      
      if (!HealthKitModule) {
        console.error('[useStepBlocker] HealthKitModule not available');
        return false;
      }
      
      console.log('[useStepBlocker] Requesting HealthKit permissions...');
      await HealthKitModule.requestPermissions();
      const authorized = await HealthKitModule.checkAuthorizationStatus();
      if (authorized) setIsAuthorized(true);
      console.log('[useStepBlocker] HealthKit authorization result:', authorized);
      return authorized;
    } catch (e) {
      console.error('HealthKit auth failed:', e);
      return false;
    }
  };

  const requestScreenTimeAuth = async (): Promise<boolean> => {
    try {
      // Direct access during authorization - bypass modulesReady check
      // This ensures iOS permission dialogs appear immediately
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule?.requestAuthorization) {
        console.error('[useStepBlocker] BlockerModule.requestAuthorization not available');
        return false;
      }
      
      console.log('[useStepBlocker] Requesting Screen Time permissions...');
      await BlockerModule.requestAuthorization();
      console.log('[useStepBlocker] Screen Time authorization completed');
      return true;
    } catch (e) {
      console.error('ScreenTime auth failed:', e);
      return false;
    }
  };

  const pickApps = async () => {
    try {
      // Direct access during app selection - bypass modulesReady check
      // This ensures the app picker appears immediately
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule) {
        console.error('[useStepBlocker] BlockerModule not available for app selection');
        return;
      }
      
      console.log('[useStepBlocker] Requesting app selection...');
      
      // Re-request authorization just in case, though UI should handle it
      if (BlockerModule.requestAuthorization) {
        await BlockerModule.requestAuthorization();
      }
      
      const count = await BlockerModule.presentAppPicker();
      console.log('[useStepBlocker] App selection completed, count:', count);
      
      setBlockedAppsCount(count);
      await AsyncStorage.setItem(BLOCKED_APPS_COUNT_KEY, count.toString());
    } catch (e) {
      console.error('[useStepBlocker] Pick apps failed:', e);
    }
  };

  const completeOnboarding = async () => {
    await AsyncStorage.setItem(ONBOARDING_KEY, 'true');
    setIsOnboarded(true);
    sync();
  };

  const setLevel = async (newLevel: Level) => {
    if (activeMode) return false;
    setLevelState(newLevel);
    await AsyncStorage.setItem(LEVEL_KEY, newLevel);
    stepsUsedForEarningRef.current = 0;
    return true;
  };

  const startActiveMode = async () => {
    if (activeMode) return false;
    setActiveMode('earn');
    await AsyncStorage.setItem(ACTIVE_MODE_KEY, 'earn');
    sync();
    return true;
  };

  const stopActiveMode = async () => {
    setActiveMode(null);
    await AsyncStorage.removeItem(ACTIVE_MODE_KEY);
    try {
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      if (BlockerModule) BlockerModule.toggleBlocking(false);
    } catch (e) {
      console.error('[useStepBlocker] stopActiveMode failed:', e);
    }
    return true;
  };

  const unlockApps = useCallback(async (minutes: number): Promise<boolean> => {
    try {
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule?.unlockApps) {
        Alert.alert('Error', 'Unlock feature not available');
        return false;
      }
      
      const result = await BlockerModule.unlockApps(minutes);
      setWalletBalance(result.balance || 0);
      if (result.endTime) {
        setUnlockSessionEndTime(result.endTime * 1000);
        setUnlockSessionDuration(minutes);
      }
      return true;
    } catch (e: any) {
      console.error('[useStepBlocker] Unlock failed:', e);
      Alert.alert('Out of minutes ⏳', 'Your time bank is empty. Walk more to earn time!');
      return false;
    }
  }, []);

  const endSessionEarly = useCallback(async (): Promise<boolean> => {
    try {
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule?.endSessionEarly) {
        Alert.alert('Error', 'End session feature not available');
        return false;
      }
      
      const result = await BlockerModule.endSessionEarly();
      setWalletBalance(prev => prev + (result.refunded || 0));
      setUnlockSessionEndTime(null);
      setUnlockSessionDuration(0);
      return true;
    } catch (e: any) {
      console.error('[useStepBlocker] End session failed:', e);
      Alert.alert('Error', e.message || 'Failed to end session');
      return false;
    }
  }, []);

  // Blocking state effect
  useEffect(() => {
    try {
      const modules = NativeModules as any;
      const BlockerModule = modules?.BlockerModule;
      
      if (!BlockerModule || activeMode !== 'earn') {
        if (BlockerModule) BlockerModule.toggleBlocking(false);
        return;
      }
      
      const hasActiveSession = unlockSessionEndTime && unlockSessionEndTime > Date.now();
      BlockerModule.toggleBlocking(!hasActiveSession);
    } catch (e) {
      console.error('[useStepBlocker] Blocking state effect failed:', e);
    }
  }, [activeMode, unlockSessionEndTime]);

  // Calculate remaining time
  const remainingTime = unlockSessionEndTime && unlockSessionEndTime > Date.now()
    ? Math.max(0, (unlockSessionEndTime - Date.now()) / 1000)
    : 0;

  return {
    currentSteps,
    blockedAppsCount,
    isOnboarded,
    activeMode,
    level,
    remainingTime,
    walletBalance,
    unlockSessionEndTime,
    unlockSessionDuration,
    timeUntilReset,
    screenDailyAverageSeconds,
    setLevel,
    startActiveMode,
    stopActiveMode,
    pickApps,
    requestHealthAuth,
    requestScreenTimeAuth,
    completeOnboarding,
    unlockApps,
    endSessionEarly,
    syncWalletBalance,
  };
};

