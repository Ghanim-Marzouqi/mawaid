import { View, Text } from 'react-native';
import { Link } from 'expo-router';

export default function NotFoundScreen() {
  return (
    <View className="flex-1 justify-center items-center bg-white">
      <Text
        className="text-2xl text-slate-900 mb-4"
        style={{ fontFamily: 'IBMPlexArabic-Bold' }}
      >
        الصفحة غير موجودة
      </Text>
      <Link href="/" className="text-blue-600">
        <Text style={{ fontFamily: 'IBMPlexArabic-Regular' }}>
          العودة للرئيسية
        </Text>
      </Link>
    </View>
  );
}
