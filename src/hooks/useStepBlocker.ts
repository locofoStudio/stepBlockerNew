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
  const getModules = useCallback(() => {
    try {
      const modules = NativeModules as any;
      return {
        HealthKitModule: modules.HealthKitModule,
        WidgetBridgeModule: modules.WidgetBridgeModule,
        BlockerModule: modules.BlockerModule,
        ScreenTimeModule: modules.ScreenTimeModule,
      };
    } catch (e) {
      console.error('Error accessing NativeModules:', e);
      return {
        HealthKitModule: null,
        WidgetBridgeModule: null,
        BlockerModule: null,
        ScreenTimeModule: null,
      };
    }
  }, []);

  // Initialize - COMPLETELY REMOVED AsyncStorage from init
  // Only check AsyncStorage when user completes onboarding
  // This keeps the UI fully responsive - NO BLOCKING OPERATIONS
  useEffect(() => {
    // Do nothing during init - just let the UI render
    // AsyncStorage will only be checked when completeOnboarding is called
    console.log('[useStepBlocker] Initialization complete - UI should be responsive');
  }, []);

  // Sync: Get steps, calculate earned minutes, add to wallet
  const sync = useCallback(async () => {
    const { HealthKitModule, BlockerModule, WidgetBridgeModule } = getModules();
    if (!HealthKitModule || !BlockerModule) return;
    // WidgetBridgeModule disabled for now
    if (!isAuthorized) return;
    
    try {
      const steps = await HealthKitModule.getTodaySteps();
      setCurrentSteps(steps);
      
      if (activeMode !== 'earn') {
        BlockerModule.toggleBlocking(false);
        // WidgetBridgeModule disabled for now
        // WidgetBridgeModule?.updateWidgetData(
        //   walletBalance,
        //   unlockSessionEndTime || 0,
        //   timeUntilReset,
        //   screenDailyAverageSeconds,
        //   steps
        // );
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
      
      // Update widget - DISABLED for now
      // WidgetBridgeModule?.updateWidgetData(
      //   walletBalance,
      //   unlockSessionEndTime || 0,
      //   timeUntilReset,
      //   screenDailyAverageSeconds,
      //   steps
      // );
    } catch (e) {
      console.error('Sync failed:', e);
    }
  }, [isAuthorized, activeMode, level, walletBalance, unlockSessionEndTime, timeUntilReset, screenDailyAverageSeconds, getModules]);

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
    const { HealthKitModule } = getModules();
    if (!HealthKitModule) return;
    
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
  }, [isAuthorized, activeMode, sync, getModules]);

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
    const { BlockerModule } = getModules();
    if (!BlockerModule?.getWalletBalance) return;
    try {
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
      console.log('Wallet sync failed:', e);
    }
  }, [getModules]);

  // Public functions
  const requestHealthAuth = async (): Promise<boolean> => {
    const { HealthKitModule } = getModules();
    if (!HealthKitModule) return false;
    try {
      await HealthKitModule.requestPermissions();
      const authorized = await HealthKitModule.checkAuthorizationStatus();
      if (authorized) setIsAuthorized(true);
      return authorized;
    } catch (e) {
      console.error('HealthKit auth failed:', e);
      return false;
    }
  };

  const requestScreenTimeAuth = async (): Promise<boolean> => {
    const { BlockerModule } = getModules();
    if (!BlockerModule?.requestAuthorization) return false;
    try {
      await BlockerModule.requestAuthorization();
      return true;
    } catch (e) {
      console.error('ScreenTime auth failed:', e);
      return false;
    }
  };

  const pickApps = async () => {
    const { BlockerModule } = getModules();
    if (!BlockerModule) return;
    try {
      if (BlockerModule.requestAuthorization) {
        await BlockerModule.requestAuthorization();
      }
      const count = await BlockerModule.presentAppPicker();
      setBlockedAppsCount(count);
      await AsyncStorage.setItem(BLOCKED_APPS_COUNT_KEY, count.toString());
    } catch (e) {
      console.error('Pick apps failed:', e);
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
    const { BlockerModule } = getModules();
    if (BlockerModule) BlockerModule.toggleBlocking(false);
    return true;
  };

  const unlockApps = useCallback(async (minutes: number): Promise<boolean> => {
    const { BlockerModule } = getModules();
    if (!BlockerModule?.unlockApps) {
      Alert.alert('Error', 'Unlock feature not available');
      return false;
    }
    try {
      const result = await BlockerModule.unlockApps(minutes);
      setWalletBalance(result.balance || 0);
      if (result.endTime) {
        setUnlockSessionEndTime(result.endTime * 1000);
        setUnlockSessionDuration(minutes);
      }
      return true;
    } catch (e: any) {
      console.error('Unlock failed:', e);
      Alert.alert('Out of minutes ⏳', 'Your time bank is empty. Walk more to earn time!');
      return false;
    }
  }, [getModules]);

  const endSessionEarly = useCallback(async (): Promise<boolean> => {
    const { BlockerModule } = getModules();
    if (!BlockerModule?.endSessionEarly) {
      Alert.alert('Error', 'End session feature not available');
      return false;
    }
    try {
      const result = await BlockerModule.endSessionEarly();
      setWalletBalance(prev => prev + (result.refunded || 0));
      setUnlockSessionEndTime(null);
      setUnlockSessionDuration(0);
      return true;
    } catch (e: any) {
      console.error('End session failed:', e);
      Alert.alert('Error', e.message || 'Failed to end session');
      return false;
    }
  }, [getModules]);

  // Blocking state effect
  useEffect(() => {
    const { BlockerModule } = getModules();
    if (!BlockerModule || activeMode !== 'earn') {
      if (BlockerModule) BlockerModule.toggleBlocking(false);
      return;
    }
    const hasActiveSession = unlockSessionEndTime && unlockSessionEndTime > Date.now();
    BlockerModule.toggleBlocking(!hasActiveSession);
  }, [activeMode, unlockSessionEndTime, getModules]);

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

