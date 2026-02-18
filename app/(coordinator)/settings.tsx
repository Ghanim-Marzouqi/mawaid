import { View, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuthStore } from '@/stores/authStore';
import { STRINGS } from '@/constants/strings';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export default function CoordinatorSettings() {
  const { profile, signOut } = useAuthStore();

  return (
    <SafeAreaView className="flex-1 bg-slate-50" edges={['bottom']}>
      <View className="flex-1 px-4 pt-4">
        <Card>
          <View className="mb-4">
            <Text
              className="text-sm text-slate-500 mb-1"
              style={{ fontFamily: 'IBMPlexArabic-Regular' }}
            >
              {STRINGS.name}
            </Text>
            <Text
              className="text-lg text-slate-900"
              style={{ fontFamily: 'IBMPlexArabic-Medium' }}
            >
              {profile?.full_name}
            </Text>
          </View>
          <View className="mb-4">
            <Text
              className="text-sm text-slate-500 mb-1"
              style={{ fontFamily: 'IBMPlexArabic-Regular' }}
            >
              {STRINGS.role}
            </Text>
            <Text
              className="text-lg text-slate-900"
              style={{ fontFamily: 'IBMPlexArabic-Medium' }}
            >
              {STRINGS.coordinator}
            </Text>
          </View>
        </Card>

        <View className="mt-6">
          <Button
            title={STRINGS.signOut}
            onPress={signOut}
            variant="danger"
          />
        </View>
      </View>
    </SafeAreaView>
  );
}
