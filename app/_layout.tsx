import { useEffect } from 'react';
import { I18nManager, ActivityIndicator, View } from 'react-native';
import { Slot, useRouter, useSegments } from 'expo-router';
import { useFonts } from 'expo-font';
import { StatusBar } from 'expo-status-bar';
import { useAuthStore } from '@/stores/authStore';
import { useRealtimeSubscriptions } from '@/hooks/useRealtimeSubscriptions';
import '../global.css';

// Force RTL before any rendering
if (!I18nManager.isRTL) {
  I18nManager.forceRTL(true);
  I18nManager.allowRTL(true);
}

export default function RootLayout() {
  const router = useRouter();
  const segments = useSegments();
  const { session, profile, isLoading, initialize } = useAuthStore();

  const [fontsLoaded] = useFonts({
    'IBMPlexArabic-Regular': require('@/assets/fonts/IBMPlexSansArabic-Regular.ttf'),
    'IBMPlexArabic-Medium': require('@/assets/fonts/IBMPlexSansArabic-Medium.ttf'),
    'IBMPlexArabic-Bold': require('@/assets/fonts/IBMPlexSansArabic-Bold.ttf'),
  });

  // Set up realtime subscriptions
  useRealtimeSubscriptions();

  useEffect(() => {
    initialize();
  }, []);

  useEffect(() => {
    if (isLoading || !fontsLoaded) return;

    const inAuthGroup = segments[0] === 'login';

    if (!session && !inAuthGroup) {
      router.replace('/login');
    } else if (session && profile) {
      const targetGroup = `(${profile.role})`;
      if (segments[0] !== targetGroup) {
        router.replace(`/${targetGroup}/` as any);
      }
    }
  }, [session, profile, isLoading, segments, fontsLoaded]);

  if (isLoading || !fontsLoaded) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <>
      <StatusBar style="dark" />
      <Slot />
    </>
  );
}
