import { View, Text, TextInput, type TextInputProps } from 'react-native';

interface InputProps extends TextInputProps {
  label: string;
  error?: string;
}

export function Input({ label, error, ...props }: InputProps) {
  return (
    <View className="mb-4">
      <Text
        className="text-sm text-slate-600 mb-2"
        style={{ fontFamily: 'IBMPlexArabic-Medium' }}
      >
        {label}
      </Text>
      <TextInput
        className={`bg-slate-50 border rounded-xl px-4 py-3 text-base text-slate-900 ${
          error ? 'border-red-400' : 'border-slate-200'
        }`}
        style={{
          fontFamily: 'IBMPlexArabic-Regular',
          textAlign: 'right',
          writingDirection: 'rtl',
        }}
        placeholderTextColor="#94a3b8"
        {...props}
      />
      {error ? (
        <Text
          className="text-sm text-red-500 mt-1"
          style={{ fontFamily: 'IBMPlexArabic-Regular' }}
        >
          {error}
        </Text>
      ) : null}
    </View>
  );
}
