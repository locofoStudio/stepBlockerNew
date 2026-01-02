/**
 * @format
 */

import React from 'react';
import {AppRegistry, View, Text} from 'react-native';
import App from './App';
import {name as appName} from './app.json';

// Wrap App with error boundary
class AppWithErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('[ErrorBoundary] App Error:', error);
    console.error('[ErrorBoundary] Error Info:', errorInfo);
    console.error('[ErrorBoundary] Error Stack:', error?.stack);
  }

  render() {
    if (this.state.hasError) {
      return (
        <View style={{ flex: 1, backgroundColor: '#1C1C1E', justifyContent: 'center', alignItems: 'center', padding: 20 }}>
          <Text style={{ color: '#fff', fontSize: 18, marginBottom: 10, textAlign: 'center' }}>
            Something went wrong
          </Text>
          <Text style={{ color: '#8E8E93', fontSize: 14, textAlign: 'center' }}>
            {this.state.error?.message || 'Unknown error'}
          </Text>
        </View>
      );
    }

    return <App />;
  }
}

AppRegistry.registerComponent(appName, () => AppWithErrorBoundary);

