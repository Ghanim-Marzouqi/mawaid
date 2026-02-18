import { Tabs } from 'expo-router';
import { Text } from 'react-native';
import { STRINGS } from '@/constants/strings';
import { useNotificationStore } from '@/stores/notificationStore';

export default function CoordinatorLayout() {
  const unreadCount = useNotificationStore((s) => s.unreadCount);

  return (
    <Tabs
      screenOptions={{
        headerTitleStyle: { fontFamily: 'IBMPlexArabic-Bold' },
        tabBarLabelStyle: { fontFamily: 'IBMPlexArabic-Regular', fontSize: 11 },
        tabBarActiveTintColor: '#2563eb',
        tabBarInactiveTintColor: '#64748b',
        headerTitleAlign: 'center',
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: STRINGS.dashboard,
          tabBarIcon: ({ color }) => (
            <Text style={{ color, fontSize: 20 }}>📋</Text>
          ),
        }}
      />
      <Tabs.Screen
        name="calendar"
        options={{
          title: STRINGS.calendar,
          tabBarIcon: ({ color }) => (
            <Text style={{ color, fontSize: 20 }}>📅</Text>
          ),
        }}
      />
      <Tabs.Screen
        name="notifications"
        options={{
          title: STRINGS.notifications,
          tabBarBadge: unreadCount > 0 ? unreadCount : undefined,
          tabBarIcon: ({ color }) => (
            <Text style={{ color, fontSize: 20 }}>🔔</Text>
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: STRINGS.settings,
          tabBarIcon: ({ color }) => (
            <Text style={{ color, fontSize: 20 }}>⚙️</Text>
          ),
        }}
      />
      <Tabs.Screen
        name="create"
        options={{
          href: null,
          title: STRINGS.createAppointment,
        }}
      />
      <Tabs.Screen
        name="[id]"
        options={{
          href: null,
          title: STRINGS.appointmentDetails,
        }}
      />
    </Tabs>
  );
}
