import { View, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { STRINGS } from '@/constants/strings';
import { formatDate } from '@/utils/formatDate';

export default function CoordinatorDashboard() {
  return (
    <SafeAreaView className="flex-1 bg-slate-50" edges={['bottom']}>
      <View className="flex-1 px-4 pt-4">
        <Text
          className="text-xl text-slate-900 mb-2"
          style={{ fontFamily: 'IBMPlexArabic-Bold' }}
        >
          {STRINGS.dashboard}
        </Text>
        <Text
          className="text-slate-500 mb-6"
          style={{ fontFamily: 'IBMPlexArabic-Regular' }}
        >
          {formatDate(new Date())}
        </Text>

        <View className="bg-white rounded-xl p-4 border border-slate-200">
          <Text
            className="text-lg text-slate-900 mb-2"
            style={{ fontFamily: 'IBMPlexArabic-Medium' }}
          >
            {STRINGS.todaySchedule}
          </Text>
          <Text
            className="text-slate-400"
            style={{ fontFamily: 'IBMPlexArabic-Regular' }}
          >
            {STRINGS.noAppointments}
          </Text>
        </View>
      </View>
    </SafeAreaView>
  );
}
