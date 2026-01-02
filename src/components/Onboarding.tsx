import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
  Dimensions,
  Image,
  ActivityIndicator,
  Alert,
} from 'react-native';

const { width } = Dimensions.get('window');

interface Props {
  onComplete: () => void;
  onRequestHealth: () => Promise<boolean>;
  onRequestScreenTime: () => Promise<boolean>;
  onPickApps: () => Promise<void>;
}

export const Onboarding = ({
  onComplete,
  onRequestHealth,
  onRequestScreenTime,
  onPickApps,
}: Props) => {
  const [step, setStep] = useState(0);
  const [healthAuth, setHealthAuth] = useState(false);
  const [screenTimeAuth, setScreenTimeAuth] = useState(false);
  const [appsPicked, setAppsPicked] = useState(false);
  const [isLoadingHealth, setIsLoadingHealth] = useState(false);
  const [isLoadingScreenTime, setIsLoadingScreenTime] = useState(false);

  const handleHealthAuth = async () => {
    if (isLoadingHealth || healthAuth) return;
    
    setIsLoadingHealth(true);
    try {
      console.log("Requesting health permissions...");
      const success = await onRequestHealth();
      console.log("Health auth success:", success);
      if (success) {
        setHealthAuth(true);
      } else {
        // Permission denied - show helpful message
        Alert.alert(
          "Health Access Required",
          "Please go to Settings > Health > Data Access & Devices > StepBlocker and enable 'Steps' to track your daily activity.",
          [{ text: "OK" }]
        );
      }
    } catch (error: any) {
      console.error("Health authorization error:", error);
      // Show user-friendly error message
      const message = error?.message || "Could not authorize Health access. Please check Settings > Health > Data Access > StepBlocker.";
      Alert.alert("Health Access Required", message, [{ text: "OK" }]);
    } finally {
      setIsLoadingHealth(false);
    }
  };

  const handleScreenTimeAuth = async () => {
    if (isLoadingScreenTime || screenTimeAuth) return;
    
    setIsLoadingScreenTime(true);
    try {
      console.log("Requesting screen time permissions...");
      const success = await onRequestScreenTime();
      console.log("Screen time auth success:", success);
      if (success) {
        setScreenTimeAuth(true);
      } else {
        Alert.alert(
          "Screen Time Access Required",
          "Family Controls permission is required. Please ensure the capability is enabled in your Apple Developer account and rebuild the app.",
          [{ text: "OK" }]
        );
      }
    } catch (error: any) {
      console.error("Screen Time authorization error:", error);
      const message = error?.message || "Could not authorize Screen Time access. Please check that Family Controls capability is enabled in Apple Developer Portal.";
      Alert.alert("Screen Time Access Required", message, [{ text: "OK" }]);
    } finally {
      setIsLoadingScreenTime(false);
    }
  };
  
  const handlePickApps = async () => {
      await onPickApps();
      setAppsPicked(true);
  };

  const handleNext = () => {
    setStep(step + 1);
  };

  const handleFinish = () => {
    if (healthAuth && screenTimeAuth && appsPicked) {
        onComplete();
    }
  };

  const renderStep1_Intro = () => (
    <View style={styles.slide}>
      <View style={styles.iconContainer}>
        <Image 
          source={require('../../assets/images/logo.jpg')} 
          style={styles.logoImage}
          resizeMode="contain"
        />
      </View>
      <Text style={styles.title}>Walk to Scroll</Text>
      <Text style={styles.subtitle}>
        StepBlocker turns your steps into currency. Want to use your favorite apps? You have to earn them.
      </Text>
      <TouchableOpacity 
        style={styles.button} 
        onPress={handleNext}
        activeOpacity={0.7}
        testID="onboarding-next-button">
        <Text style={styles.buttonText}>Next</Text>
      </TouchableOpacity>
    </View>
  );

  const renderStep2_Concept = () => (
    <View style={styles.slide}>
      <View style={styles.iconContainer}>
        <Image 
          source={require('../../assets/images/logo.jpg')} 
          style={styles.logoImage}
          resizeMode="contain"
        />
      </View>
      <Text style={styles.title}>Block Distractions</Text>
      <Text style={styles.subtitle}>
        Select the apps that distract you the most. We'll block them until you reach your daily step goal.
      </Text>
      <TouchableOpacity style={styles.button} onPress={handleNext}>
        <Text style={styles.buttonText}>Let's Go</Text>
      </TouchableOpacity>
    </View>
  );

  const renderStep3_Permissions = () => (
    <View style={styles.slide}>
      <Text style={styles.title}>Setup Permissions</Text>
      <Text style={styles.subtitle}>
        We need access to your steps and screen time controls to make this work.
      </Text>

      <View style={styles.actionContainer}>
        <View style={styles.actionRow}>
          <View style={styles.textCol}>
             <Text style={styles.actionTitle}>Health Access</Text>
             <Text style={styles.actionDesc}>To track your daily steps</Text>
          </View>
          <TouchableOpacity
            style={[styles.actionBtn, healthAuth && styles.actionBtnDone]}
            onPress={handleHealthAuth}
            disabled={healthAuth || isLoadingHealth}
            activeOpacity={0.6}>
            {isLoadingHealth ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.actionBtnText}>{healthAuth ? '✓' : 'Authorize'}</Text>
            )}
          </TouchableOpacity>
        </View>

        <View style={styles.actionRow}>
          <View style={styles.textCol}>
             <Text style={styles.actionTitle}>Screen Time</Text>
             <Text style={styles.actionDesc}>To block/unblock apps</Text>
          </View>
          <TouchableOpacity
            style={[styles.actionBtn, screenTimeAuth && styles.actionBtnDone]}
            onPress={handleScreenTimeAuth}
            disabled={screenTimeAuth || isLoadingScreenTime}>
            {isLoadingScreenTime ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.actionBtnText}>{screenTimeAuth ? '✓' : 'Authorize'}</Text>
            )}
          </TouchableOpacity>
        </View>
      </View>

      <TouchableOpacity
        style={[styles.button, (!healthAuth || !screenTimeAuth) && styles.disabledButton]}
        onPress={handleNext}
        disabled={!healthAuth || !screenTimeAuth}>
        <Text style={styles.buttonText}>Next</Text>
      </TouchableOpacity>
    </View>
  );

  const renderStep4_Selection = () => (
      <View style={styles.slide}>
        <View style={styles.iconContainer}>
          <Image 
            source={require('../../assets/images/logo.jpg')} 
            style={styles.logoImage}
            resizeMode="contain"
          />
        </View>
        <Text style={styles.title}>Select Apps</Text>
        <Text style={styles.subtitle}>
          Choose the apps you want to block. You can change this later.
        </Text>
        
        <TouchableOpacity style={styles.pickButton} onPress={handlePickApps}>
            <Text style={styles.pickButtonText}>
                {appsPicked ? 'Change Selection' : 'Select Apps to Block'}
            </Text>
        </TouchableOpacity>

        {appsPicked && (
            <Text style={styles.successText}>Apps Selected ✓</Text>
        )}

        <TouchableOpacity
          style={[styles.button, !appsPicked && styles.disabledButton]}
          onPress={handleFinish}
          disabled={!appsPicked}>
          <Text style={styles.buttonText}>Get Started</Text>
        </TouchableOpacity>
      </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" />
      <View style={styles.content}>
        {step === 0 && renderStep1_Intro()}
        {step === 1 && renderStep2_Concept()}
        {step === 2 && renderStep3_Permissions()}
        {step === 3 && renderStep4_Selection()}
        
        <View style={styles.dots}>
          {[0, 1, 2, 3].map((i) => (
            <View key={i} style={[styles.dot, step === i && styles.dotActive]} />
          ))}
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#121212',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
  },
  slide: {
    flex: 1,
    padding: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconContainer: {
    width: 100,
    height: 100,
    backgroundColor: '#1C1C1E',
    borderRadius: 50,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 30,
    overflow: 'hidden',
  },
  icon: {
    fontSize: 50,
  },
  logoImage: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
    textAlign: 'center',
    marginBottom: 15,
  },
  subtitle: {
    fontSize: 16,
    color: '#AAA',
    textAlign: 'center',
    marginBottom: 40,
    lineHeight: 24,
  },
  button: {
    backgroundColor: '#00FF00',
    paddingVertical: 16,
    paddingHorizontal: 40,
    borderRadius: 30,
    marginTop: 20,
    width: '100%',
    alignItems: 'center',
  },
  disabledButton: {
      opacity: 0.3,
  },
  buttonText: {
    color: '#000',
    fontSize: 18,
    fontWeight: 'bold',
  },
  actionContainer: {
      width: '100%',
      gap: 20,
      marginBottom: 40,
  },
  actionRow: {
      flexDirection: 'row',
      backgroundColor: '#1C1C1E',
      padding: 15,
      borderRadius: 12,
      alignItems: 'center',
      justifyContent: 'space-between',
  },
  textCol: {
      flex: 1,
  },
  actionTitle: {
      color: '#fff',
      fontSize: 16,
      fontWeight: 'bold',
      marginBottom: 4,
  },
  actionDesc: {
      color: '#888',
      fontSize: 12,
  },
  actionBtn: {
      backgroundColor: '#333',
      paddingVertical: 8,
      paddingHorizontal: 16,
      borderRadius: 8,
  },
  actionBtnDone: {
      backgroundColor: '#00FF00',
  },
  actionBtnText: {
      color: '#fff',
      fontWeight: 'bold',
  },
  pickButton: {
      backgroundColor: '#333',
      padding: 20,
      borderRadius: 15,
      width: '100%',
      alignItems: 'center',
      marginBottom: 20,
      borderWidth: 1,
      borderColor: '#444',
  },
  pickButtonText: {
      color: '#fff',
      fontSize: 16,
      fontWeight: '600',
  },
  successText: {
      color: '#00FF00',
      marginBottom: 20,
  },
  dots: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingBottom: 40,
    gap: 8,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#333',
  },
  dotActive: {
    backgroundColor: '#00FF00',
    width: 20,
  },
});

