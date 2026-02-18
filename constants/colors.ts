import type { AppointmentType, AppointmentStatus } from '@/types/database';

export const COLORS = {
  primary: '#2563eb',
  primaryLight: '#dbeafe',
  background: '#f8fafc',
  surface: '#ffffff',
  text: '#0f172a',
  textSecondary: '#64748b',
  border: '#e2e8f0',
  error: '#dc2626',
  errorLight: '#fef2f2',
  success: '#16a34a',
  successLight: '#f0fdf4',
  warning: '#d97706',
  warningLight: '#fffbeb',
} as const;

export const APPOINTMENT_TYPE_COLORS: Record<AppointmentType, { bg: string; text: string; dot: string }> = {
  ministry: { bg: '#fef2f2', text: '#991b1b', dot: '#dc2626' },
  patient: { bg: '#eff6ff', text: '#1e40af', dot: '#3b82f6' },
  external: { bg: '#f0fdf4', text: '#166534', dot: '#16a34a' },
};

export const APPOINTMENT_STATUS_COLORS: Record<AppointmentStatus, { bg: string; text: string }> = {
  pending: { bg: '#fffbeb', text: '#92400e' },
  confirmed: { bg: '#f0fdf4', text: '#166534' },
  rejected: { bg: '#fef2f2', text: '#991b1b' },
  suggested: { bg: '#eff6ff', text: '#1e40af' },
  cancelled: { bg: '#f1f5f9', text: '#475569' },
};
