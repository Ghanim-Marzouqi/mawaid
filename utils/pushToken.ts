import { Platform } from 'react-native';
import { supabase } from '@/services/supabase';

export async function registerPushToken(userId: string): Promise<void> {
  // Only register on native platforms
  if (Platform.OS === 'web') return;

  try {
    // Dynamically import expo-notifications (only available on native)
    // These modules are optional and may not be installed during Phase 1
    const Notifications = require('expo-notifications');
    const Device = require('expo-device');

    if (!Device.isDevice) return;

    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }

    if (finalStatus !== 'granted') return;

    const tokenData = await Notifications.getExpoPushTokenAsync();
    const pushToken = tokenData.data;

    await supabase
      .from('profiles')
      .update({ push_token: pushToken })
      .eq('id', userId);
  } catch {
    // Push notifications not available (e.g., in development or modules not installed)
    console.warn('Push token registration skipped');
  }
}
