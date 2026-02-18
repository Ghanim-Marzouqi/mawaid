import { Pressable, Text, ActivityIndicator } from 'react-native';

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
  isLoading?: boolean;
  disabled?: boolean;
}

const variantStyles = {
  primary: {
    container: 'bg-blue-600 active:bg-blue-700',
    text: 'text-white',
    loader: '#ffffff',
  },
  secondary: {
    container: 'bg-slate-100 active:bg-slate-200 border border-slate-300',
    text: 'text-slate-900',
    loader: '#0f172a',
  },
  danger: {
    container: 'bg-red-600 active:bg-red-700',
    text: 'text-white',
    loader: '#ffffff',
  },
};

export function Button({
  title,
  onPress,
  variant = 'primary',
  isLoading = false,
  disabled = false,
}: ButtonProps) {
  const styles = variantStyles[variant];
  const isDisabled = disabled || isLoading;

  return (
    <Pressable
      onPress={onPress}
      disabled={isDisabled}
      className={`rounded-xl py-4 px-6 items-center justify-center ${styles.container} ${isDisabled ? 'opacity-50' : ''}`}
    >
      {isLoading ? (
        <ActivityIndicator color={styles.loader} />
      ) : (
        <Text
          className={`text-base ${styles.text}`}
          style={{ fontFamily: 'IBMPlexArabic-Medium' }}
        >
          {title}
        </Text>
      )}
    </Pressable>
  );
}
