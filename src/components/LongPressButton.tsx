import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Animated,
  Vibration,
} from 'react-native';

interface LongPressButtonProps {
  onComplete: () => void;
  duration?: number; // in milliseconds (default 3000ms = 3s is usually enough friction)
  buttonText?: string;
  buttonStyle?: any;
  textStyle?: any;
}

export const LongPressButton = ({ 
  onComplete, 
  duration = 10000,
  buttonText = 'STOP SESSION',
  buttonStyle,
  textStyle,
}: LongPressButtonProps) => {
  const [isPressing, setIsPressing] = useState(false);
  const progress = useRef(new Animated.Value(0)).current;

  const handlePressIn = () => {
    setIsPressing(true);
    Animated.timing(progress, {
      toValue: 1,
      duration: duration,
      useNativeDriver: false, // width doesn't support native driver
    }).start(({ finished }) => {
      if (finished) {
        Vibration.vibrate(100); // Haptic feedback when done
        onComplete();
        setIsPressing(false);
        progress.setValue(0); // Reset immediately
      }
    });
  };

  const handlePressOut = () => {
    setIsPressing(false);
    Animated.timing(progress).stop(); // Stop the animation
    Animated.spring(progress, {
      toValue: 0, // Bounce back to 0
      useNativeDriver: false,
    }).start();
  };

  const widthInterpolation = progress.interpolate({
    inputRange: [0, 1],
    outputRange: ['0%', '100%'],
  });

  return (
    <View style={styles.container}>
      {isPressing && (
        <Text style={styles.hintText}>Hold to stop...</Text>
      )}
      
      <Pressable
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        style={[styles.button, buttonStyle]}
      >
        {/* The Progress Fill Layer */}
        <Animated.View style={[styles.fill, { width: widthInterpolation }]} />

        {/* The Text Layer (On top) */}
        <Text style={[styles.text, textStyle]}>{buttonText}</Text>
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    width: '100%',
  },
  hintText: {
    color: '#888',
    marginBottom: 8,
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontFamily: 'RobotoMono-Regular',
  },
  button: {
    width: '100%',
    height: 137,
    backgroundColor: '#FF453A', // Red background for stop button
    borderRadius: 18,
    overflow: 'hidden', // Keeps the fill inside
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#FF3B30',
  },
  fill: {
    ...StyleSheet.absoluteFillObject, // Fills the button container
    backgroundColor: '#1C1C1E', // Dark fill color that reveals as you hold
  },
  text: {
    color: '#FFF',
    fontFamily: 'RobotoMono-Bold',
    fontSize: 18,
    zIndex: 1, // Ensures text stays on top of the fill
    textAlign: 'center',
  },
});

