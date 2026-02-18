import { View, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { STRINGS } from '@/constants/strings';

export default function CreateAppointment() {
  return (
    <SafeAreaView className="flex-1 bg-slate-50" edges={['bottom']}>
      <View className="flex-1 justify-center items-center px-4">
        <Text
          className="text-xl text-slate-900 mb-2"
          style={{ fontFamily: 'IBMPlexArabic-Bold' }}
        >
          {STRINGS.createAppointment}
        </Text>
        <Text
          className="text-slate-400"
          style={{ fontFamily: 'IBMPlexArabic-Regular' }}
        >
          سيتم بناء نموذج الإنشاء في المرحلة التالية
        </Text>
      </View>
    </SafeAreaView>
  );
}
