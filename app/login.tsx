import { useState } from 'react';
import { View, Text, KeyboardAvoidingView, Platform } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuthStore } from '@/stores/authStore';
import { STRINGS } from '@/constants/strings';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const signIn = useAuthStore((s) => s.signIn);

  const handleLogin = async () => {
    if (!email || !password) return;

    setError('');
    setIsLoading(true);
    try {
      await signIn(email, password);
    } catch {
      setError(STRINGS.loginError);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <SafeAreaView className="flex-1 bg-white">
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        className="flex-1"
      >
        <View className="flex-1 justify-center px-8">
          <Text
            className="text-3xl text-center mb-12 text-slate-900"
            style={{ fontFamily: 'IBMPlexArabic-Bold' }}
          >
            {STRINGS.login}
          </Text>

          <Input
            label={STRINGS.email}
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            textContentType="emailAddress"
          />

          <Input
            label={STRINGS.password}
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoComplete="password"
            textContentType="password"
          />

          {error ? (
            <Text
              className="text-red-600 text-center mb-4"
              style={{ fontFamily: 'IBMPlexArabic-Regular' }}
            >
              {error}
            </Text>
          ) : null}

          <Button
            title={STRINGS.loginButton}
            onPress={handleLogin}
            isLoading={isLoading}
          />
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}
