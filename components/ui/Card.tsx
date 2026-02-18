import { View, type ViewProps } from 'react-native';

interface CardProps extends ViewProps {
  children: React.ReactNode;
}

export function Card({ children, className, ...props }: CardProps) {
  return (
    <View
      className={`bg-white rounded-xl p-4 border border-slate-200 ${className ?? ''}`}
      {...props}
    >
      {children}
    </View>
  );
}
