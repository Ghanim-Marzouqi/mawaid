export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat('ar-SA-u-nu-arab', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date);
}

export function formatTime(date: Date): string {
  return new Intl.DateTimeFormat('ar-SA-u-nu-arab', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  }).format(date);
}

export function formatDateShort(date: Date): string {
  return new Intl.DateTimeFormat('ar-SA-u-nu-arab', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}
