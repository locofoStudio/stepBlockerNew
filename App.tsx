import React, { useState, useEffect, ErrorInfo } from 'react';
import {
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ScrollView,
  StatusBar,
  ActivityIndicator,
  Modal,
  TextInput,
  Alert,
} from 'react-native';
import { useStepBlocker } from './src/hooks/useStepBlocker';
import { Onboarding } from './src/components/Onboarding';
import { LongPressButton } from './src/components/LongPressButton';

console.log('[App] All imports completed');

// Error Boundary Component
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('App Error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <SafeAreaView style={[styles.container, styles.centered]}>
          <Text style={{ color: '#fff', fontSize: 18, marginBottom: 10 }}>
            Something went wrong
          </Text>
          <Text style={{ color: '#8E8E93', fontSize: 14 }}>
            {this.state.error?.message || 'Unknown error'}
          </Text>
        </SafeAreaView>
      );
    }

    return this.props.children;
  }
}

function App(): React.JSX.Element {
  console.log('[App] Component rendering...');
  console.log('[App] About to call useStepBlocker hook...');
  console.log('[App] useStepBlocker function exists:', typeof useStepBlocker);
  console.log('[App] useStepBlocker function:', useStepBlocker);
  
  let hookResult: any;
  try {
    console.log('[App] Calling useStepBlocker...');
    hookResult = useStepBlocker();
    console.log('[App] useStepBlocker returned:', !!hookResult);
    console.log('[App] hookResult keys:', Object.keys(hookResult || {}));
  } catch (error) {
    console.error('[App] ERROR calling useStepBlocker:', error);
    throw error; // Re-throw to let error boundary catch it
  }
  
  const {
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
  } = hookResult;
  
  console.log('[App] Hook completed, isOnboarded:', isOnboarded);
  
  const [showCustomAmountModal, setShowCustomAmountModal] = useState(false);
  const [customAmount, setCustomAmount] = useState('');

  // Calculate derived values (before early returns)
  const isCurrentModeActive = activeMode === 'earn';
  const hasActiveUnlockSession = unlockSessionEndTime && unlockSessionEndTime > Date.now();

  // Sync wallet balance periodically
  useEffect(() => {
    if (isOnboarded) {
      syncWalletBalance();
      const interval = setInterval(() => {
        syncWalletBalance();
      }, 5000); // Sync every 5 seconds
      return () => clearInterval(interval);
    }
  }, [isOnboarded, syncWalletBalance]);

  // Check for expired sessions
  useEffect(() => {
    if (hasActiveUnlockSession) {
      const interval = setInterval(() => {
        syncWalletBalance();
      }, 1000); // Check every second when session is active
      return () => clearInterval(interval);
    }
  }, [hasActiveUnlockSession, syncWalletBalance]);

  // Format time as MM:SS (minutes:seconds)
  const formatTime = (totalSeconds: number): string => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = Math.floor(totalSeconds % 60);
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  // Format seconds as HH:MM (hours:minutes)
  const formatHHMMFromSeconds = (totalSeconds: number): string => {
    const hours = Math.floor(totalSeconds / 3600);
    const mins = Math.floor((totalSeconds % 3600) / 60);
    return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
  };

  // Format minutes as HH:MM
  const formatMinutes = (totalMinutes: number): string => {
    const hours = Math.floor(totalMinutes / 60);
    const mins = Math.floor(totalMinutes % 60);
    return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
  };

  // Calculate remaining session time
  const getRemainingSessionTime = (): number => {
    if (!unlockSessionEndTime) return 0;
    const remaining = Math.max(0, (unlockSessionEndTime - Date.now()) / 1000);
    return remaining;
  };

  // Early returns AFTER all hooks
  console.log('[App] Checking isOnboarded:', isOnboarded);
  // Note: isOnboarded now initializes to false instead of null to prevent infinite loading
  // If AsyncStorage succeeds, it will update to true for onboarded users
  
  if (!isOnboarded) {
      console.log('[App] Rendering Onboarding, isOnboarded:', isOnboarded);
      return (
          <Onboarding
            onComplete={completeOnboarding}
            onRequestHealth={requestHealthAuth}
            onRequestScreenTime={requestScreenTimeAuth}
            onPickApps={pickApps}
          />
      );
  }

  const handleUnlock = async (minutes: number) => {
    if (walletBalance < minutes) {
      Alert.alert('Insufficient Balance', `You need ${minutes} minutes but only have ${walletBalance} minutes in your wallet. Walk more to earn time!`);
      return;
    }
    await unlockApps(minutes);
  };

  const handleCustomUnlock = async () => {
    const minutes = parseInt(customAmount, 10);
    if (isNaN(minutes) || minutes <= 0) {
      Alert.alert('Invalid Amount', 'Please enter a valid number of minutes');
      return;
    }
    if (minutes > walletBalance) {
      Alert.alert('Insufficient Balance', `You need ${minutes} minutes but only have ${walletBalance} minutes in your wallet.`);
      return;
    }
    await unlockApps(minutes);
    setShowCustomAmountModal(false);
    setCustomAmount('');
  };

  const handleEndSession = async () => {
    Alert.alert(
      'End Session Early?',
      'You will be refunded for the remaining time. Apps will be unblocked.',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'End Session', 
          style: 'destructive',
          onPress: async () => {
            await endSessionEarly();
            await stopActiveMode(); // Stop the session and unblock apps
          }
        }
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" />
      <View style={styles.content}>
        <ScrollView contentContainerStyle={styles.scrollContent}>
          <View style={styles.pageWidth}>
          {/* Zone 1: The Wallet (Top 35%) */}
          <View style={styles.header}>
            <Text style={styles.title}>StepBlocker</Text>
            <Text style={styles.subtitle}>Turn steps into screen time</Text>
          </View>

          {/* Dashboard Card */}
          <View style={styles.dashboardOuter}>
            <View style={styles.dashboardInner}>
              {/* Top Metrics Row */}
              <View style={styles.topMetricsRow}>
                <View style={styles.metricCard}>
                  <Text style={styles.metricLabel}>Time Until{'\n'}Reset</Text>
                  <Text style={styles.metricValue}>{formatHHMMFromSeconds(timeUntilReset)}</Text>
                </View>
                <View style={styles.metricCard}>
                  <Text
                    style={styles.metricLabel}
                    numberOfLines={2}
                    adjustsFontSizeToFit
                    minimumFontScale={0.85}
                  >
                    {'Screen\u00A0Daily'}{'\n'}Average
                  </Text>
                  <Text style={styles.metricValue}>{formatHHMMFromSeconds(screenDailyAverageSeconds)}</Text>
                </View>
                <View style={styles.metricCard}>
                  <Text style={styles.metricLabel}>Steps{'\n'}Walked</Text>
                  <Text style={[styles.metricValue, styles.metricValueGreen]}>{currentSteps.toLocaleString()}</Text>
                </View>
              </View>

              {/* Main Display Cards */}
              <View style={styles.mainDisplayRow}>
                <View style={[styles.mainDisplayCard, styles.mainDisplayCardHighlighted]}>
                  <View style={styles.mainDisplayLabelContainer}>
                    <Text style={styles.mainDisplayLabel}>Time Left</Text>
                  </View>
                  <Text style={[styles.mainDisplayValue, styles.mainDisplayValueRed]}>
                    {hasActiveUnlockSession ? formatTime(getRemainingSessionTime()) : formatTime(0)}
                  </Text>
                </View>
                <View style={styles.mainDisplayCard}>
                  <View style={styles.mainDisplayLabelContainer}>
                    <Text style={styles.mainDisplayLabel}>Time Earned</Text>
                  </View>
                  <Text style={[styles.mainDisplayValue, styles.mainDisplayValueOrange]}>
                    {formatMinutes(walletBalance)}
                  </Text>
                </View>
              </View>
            </View>
          </View>

          {/* Zone 2: Unlock Your Apps Section */}
          <View style={styles.fieldset}>
            <View style={styles.fieldsetLegend}>
              <Text style={styles.fieldsetLegendText}>Unlock Your Apps</Text>
            </View>

            <View style={styles.unlockButtonsRow}>
              <TouchableOpacity
                style={[styles.unlockButton, walletBalance < 5 && styles.unlockButtonDisabled]}
                onPress={() => handleUnlock(5)}
                disabled={walletBalance < 5}
                activeOpacity={0.85}
              >
                <Text style={styles.unlockButtonTopText}>Unlock</Text>
                <Text style={styles.unlockButtonBottomText}>
                  <Text style={styles.unlockButtonBottomBold}>5</Text> mins
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.unlockButton, walletBalance < 10 && styles.unlockButtonDisabled]}
                onPress={() => handleUnlock(10)}
                disabled={walletBalance < 10}
                activeOpacity={0.85}
              >
                <Text style={styles.unlockButtonTopText}>Unlock</Text>
                <Text style={styles.unlockButtonBottomText}>
                  <Text style={styles.unlockButtonBottomBold}>10</Text> mins
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.unlockButton, walletBalance < 20 && styles.unlockButtonDisabled]}
                onPress={() => handleUnlock(20)}
                disabled={walletBalance < 20}
                activeOpacity={0.85}
              >
                <Text style={styles.unlockButtonTopText}>Unlock</Text>
                <Text style={styles.unlockButtonBottomText}>
                  <Text style={styles.unlockButtonBottomBold}>20</Text> mins
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Zone 3: Challenge Selector */}
          <View style={styles.fieldset}>
            <View style={styles.fieldsetLegend}>
              <Text style={styles.fieldsetLegendText}>Challenge</Text>
            </View>

            <View style={styles.challengeButtonsRow}>
              <TouchableOpacity
                style={[styles.challengeButton, level === 'easy' && styles.challengeButtonActive]}
                onPress={() => setLevel('easy')}
                disabled={isCurrentModeActive}
              >
                <Text style={[styles.challengeButtonText, level === 'easy' && styles.challengeButtonTextActive]}>
                  Easy
                </Text>
                <Text style={styles.challengeButtonSubtext}>1000k / 20min</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.challengeButton, level === 'medium' && styles.challengeButtonActive]}
                onPress={() => setLevel('medium')}
                disabled={isCurrentModeActive}
              >
                <Text style={[styles.challengeButtonText, level === 'medium' && styles.challengeButtonTextActive]}>
                  Medium
                </Text>
                <Text style={styles.challengeButtonSubtext}>1000k / 10min</Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.challengeButton, level === 'hard' && styles.challengeButtonActive]}
                onPress={() => setLevel('hard')}
                disabled={isCurrentModeActive}
              >
                <Text style={[styles.challengeButtonText, level === 'hard' && styles.challengeButtonTextActive]}>
                  Hard
                </Text>
                <Text style={styles.challengeButtonSubtext}>1000k / 5min</Text>
              </TouchableOpacity>
            </View>
            
            {isCurrentModeActive && (
              <Text style={styles.challengeInstruction}>
                Stop the session to change challenge level
              </Text>
            )}
          </View>

          <TouchableOpacity style={styles.selectAppsButton} onPress={pickApps} activeOpacity={0.85}>
            <Text style={styles.selectAppsButtonText}>Edit Blocked Apps ({blockedAppsCount})</Text>
          </TouchableOpacity>
          </View>
        </ScrollView>
      </View>
      
      <View style={styles.footer}>
        {isCurrentModeActive ? (
          <LongPressButton
            duration={10000}
            onComplete={handleEndSession}
            buttonText="HOLD TO STOP"
            buttonStyle={styles.stopButtonContainer}
            textStyle={styles.stopButtonText}
          />
        ) : (
          <TouchableOpacity
            style={styles.startButton}
            onPress={startActiveMode}
            activeOpacity={0.85}
          >
            <Text style={styles.startButtonText}>START</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Custom Amount Modal */}
      <Modal
        visible={showCustomAmountModal}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowCustomAmountModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Unlock Custom Amount</Text>
            <Text style={styles.modalSubtitle}>Available: {walletBalance} minutes</Text>
            <TextInput
              style={styles.modalInput}
              value={customAmount}
              onChangeText={setCustomAmount}
              placeholder="Enter minutes"
              keyboardType="number-pad"
              placeholderTextColor="#8E8E93"
            />
            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonCancel]}
                onPress={() => {
                  setShowCustomAmountModal(false);
                  setCustomAmount('');
                }}
              >
                <Text style={styles.modalButtonTextCancel}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalButtonConfirm]}
                onPress={handleCustomUnlock}
              >
                <Text style={styles.modalButtonTextConfirm}>Unlock</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1C1C1E',
  },
  content: {
    flex: 1,
  },
  centered: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollContent: {
    paddingHorizontal: 6,
    paddingTop: 18,
    flexGrow: 1,
    paddingBottom: 120,
    alignItems: 'center',
  },
  pageWidth: {
    width: '100%',
    maxWidth: 360,
  },
  header: {
    alignItems: 'center',
    marginBottom: 20,
    marginTop: 10,
    justifyContent: 'center',
  },
  title: {
    fontSize: 20,
    color: '#fff',
    fontFamily: 'DotGothic16-Regular',
    letterSpacing: 1,
  },
  subtitle: {
    fontSize: 14,
    color: '#8E8E93',
    fontFamily: 'RobotoMono-Regular',
    marginTop: 4,
    textAlign: 'center',
  },
  dashboardOuter: {
    backgroundColor: '#353535',
    borderRadius: 13,
    padding: 6,
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
    elevation: 6,
    marginBottom: 26,
    width: '100%',
  },
  dashboardInner: {
    backgroundColor: '#222',
    borderRadius: 13,
    borderWidth: 1,
    borderColor: '#6f6f6f',
    padding: 12,
  },
  // Top Metrics Row
  topMetricsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
    marginBottom: 16,
  },
  metricCard: {
    flex: 1,
    backgroundColor: '#222',
    padding: 12,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#444343',
    alignItems: 'flex-start',
  },
  metricLabel: {
    color: '#979797',
    fontSize: 12,
    fontFamily: 'RobotoMono-Regular',
    marginBottom: 8,
    textAlign: 'left',
  },
  metricValue: {
    color: '#fff',
    fontSize: 16,
    fontFamily: 'RobotoMono-Regular',
    textAlign: 'left',
  },
  metricValueGreen: {
    color: '#4AF626',
  },
  // Main Display Row
  mainDisplayRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
    marginBottom: 0,
  },
  mainDisplayCard: {
    flex: 1,
    backgroundColor: '#222',
    padding: 16,
    borderRadius: 5,
    borderWidth: 1,
    borderColor: '#6f6f6f',
    position: 'relative',
    minHeight: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
  mainDisplayLabelContainer: {
    position: 'absolute',
    top: -6,
    left: 10,
    backgroundColor: '#222',
    paddingHorizontal: 4,
  },
  mainDisplayLabel: {
    color: '#979797',
    fontSize: 12,
    fontFamily: 'RobotoMono-Regular',
  },
  mainDisplayValue: {
    fontSize: 32,
    fontFamily: 'RobotoMono-Regular',
    lineHeight: 56,
    textAlign: 'center',
  },
  mainDisplayCardHighlighted: {
    borderColor: '#FFFFFF',
  },
  mainDisplayValueRed: {
    color: '#F44141',
  },
  mainDisplayValueOrange: {
    color: '#F46E41',
  },
  // Fieldset style section ("Unlock Your Apps")
  fieldset: {
    width: '100%',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#6f6f6f',
    paddingTop: 22,
    paddingBottom: 16,
    paddingHorizontal: 14,
    marginTop: 6,
    marginBottom: 18,
  },
  fieldsetLegend: {
    position: 'absolute',
    top: -10,
    left: 10,
    alignItems: 'flex-start',
  },
  fieldsetLegendText: {
    backgroundColor: '#1C1C1E',
    paddingHorizontal: 12,
    color: '#979797',
    fontFamily: 'RobotoMono-Regular',
    fontSize: 14,
  },
  unlockButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 12,
    marginBottom: 0,
  },
  unlockButton: {
    backgroundColor: '#2A2A2A',
    paddingVertical: 14,
    paddingHorizontal: 18,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#6f6f6f',
    minWidth: 98,
    alignItems: 'center',
    justifyContent: 'center',
  },
  unlockButtonDisabled: {
    opacity: 0.5,
    borderColor: '#444343',
  },
  selectAppsButton: {
    backgroundColor: '#4AF626',
    paddingVertical: 10,
    paddingHorizontal: 18,
    borderRadius: 8,
    alignItems: 'center',
    alignSelf: 'center',
    minWidth: 160,
    marginTop: 14,
    marginBottom: 10,
  },
  selectAppsButtonText: {
    color: '#000',
    fontFamily: 'RobotoMono-Bold',
    fontSize: 14,
    letterSpacing: 0.5,
  },
  blockedAppsCount: {
    color: '#979797',
    fontSize: 14,
    fontFamily: 'RobotoMono-Regular',
    textAlign: 'center',
    marginBottom: 18,
  },
  unlockButtonTopText: {
    color: '#979797',
    fontSize: 13,
    fontFamily: 'RobotoMono-Regular',
    marginBottom: 6,
  },
  unlockButtonBottomText: {
    color: '#fff',
    fontSize: 14,
    fontFamily: 'RobotoMono-Regular',
  },
  unlockButtonBottomBold: {
    fontFamily: 'RobotoMono-Bold',
  },
  // Zone 3: Challenge Selector
  challengeButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 12,
    marginBottom: 8,
  },
  challengeButton: {
    backgroundColor: '#2A2A2A',
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#6f6f6f',
    minWidth: 102,
    alignItems: 'center',
    justifyContent: 'center',
  },
  challengeButtonActive: {
    borderColor: '#fff',
  },
  challengeButtonText: {
    color: '#4AF626',
    fontSize: 14,
    fontFamily: 'RobotoMono-Regular',
    marginBottom: 4,
  },
  challengeButtonTextActive: {
    color: '#4AF626',
    fontFamily: 'RobotoMono-Bold',
  },
  challengeButtonSubtext: {
    color: '#979797',
    fontSize: 10,
    fontFamily: 'RobotoMono-Regular',
  },
  challengeInstruction: {
    color: '#979797',
    fontSize: 12,
    fontFamily: 'RobotoMono-Regular',
    textAlign: 'center',
    marginTop: 8,
  },
  footer: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingHorizontal: 0,
  },
  startButton: {
    backgroundColor: '#353535',
    height: 112,
    borderRadius: 18,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: -1 },
    elevation: 6,
  },
  startButtonText: {
    color: '#FFFFFF',
    fontFamily: 'RobotoMono-Bold',
    fontSize: 18,
    textAlign: 'center',
  },
  stopButtonContainer: {
    height: 120,
    backgroundColor: '#FF3B30',
    borderRadius: 0,
  },
  stopButtonText: {
    color: '#fff',
    fontFamily: 'RobotoMono-Bold',
    fontSize: 18,
  },
  // Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#2C2C2E',
    borderRadius: 16,
    padding: 24,
    width: '80%',
    maxWidth: 400,
  },
  modalTitle: {
    color: '#fff',
    fontSize: 20,
    fontFamily: 'RobotoMono-Bold',
    marginBottom: 8,
    textAlign: 'center',
  },
  modalSubtitle: {
    color: '#8E8E93',
    fontSize: 14,
    fontFamily: 'RobotoMono-Regular',
    marginBottom: 16,
    textAlign: 'center',
  },
  modalInput: {
    backgroundColor: '#1C1C1E',
    borderRadius: 8,
    padding: 16,
    color: '#fff',
    fontSize: 18,
    fontFamily: 'RobotoMono-Regular',
    marginBottom: 24,
    borderWidth: 1,
    borderColor: '#444343',
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
  },
  modalButton: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  modalButtonCancel: {
    backgroundColor: '#2C2C2E',
    borderWidth: 1,
    borderColor: '#444343',
  },
  modalButtonConfirm: {
    backgroundColor: '#4AF626',
  },
  modalButtonTextCancel: {
    color: '#fff',
    fontSize: 16,
    fontFamily: 'RobotoMono-Bold',
  },
  modalButtonTextConfirm: {
    color: '#000',
    fontSize: 16,
    fontFamily: 'RobotoMono-Bold',
  },
});

export default App;
