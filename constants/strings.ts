export const STRINGS = {
  // Auth
  login: 'تسجيل الدخول',
  email: 'البريد الإلكتروني',
  password: 'كلمة المرور',
  loginButton: 'دخول',
  loginError: 'البريد أو كلمة المرور غير صحيحة',

  // Appointment types
  ministry: 'إجتماع وزارة',
  patient: 'موعد مريض',
  external: 'موعد خارجي',

  // Statuses
  pending: 'بانتظار الموافقة',
  confirmed: 'مؤكد',
  rejected: 'مرفوض',
  suggested: 'مقترح وقت بديل',
  cancelled: 'ملغي',

  // Actions
  approve: 'موافقة',
  reject: 'رفض',
  suggestAlternative: 'اقتراح وقت بديل',
  acceptSuggestion: 'قبول الاقتراح',
  rejectSuggestion: 'رفض الاقتراح',
  cancel: 'إلغاء',
  save: 'حفظ',
  create: 'إنشاء',
  delete: 'حذف',
  signOut: 'تسجيل الخروج',

  // Notifications
  notifications: 'الإشعارات',
  noNotifications: 'لا توجد إشعارات',

  // Calendar
  calendar: 'التقويم',
  today: 'اليوم',
  noAppointments: 'لا توجد مواعيد',

  // Dashboard
  dashboard: 'الرئيسية',
  pendingCount: 'بانتظار الموافقة',
  confirmedCount: 'مؤكدة',
  todaySchedule: 'جدول اليوم',

  // Create / Form
  createAppointment: 'إنشاء موعد',
  appointmentTitle: 'عنوان الموعد',
  appointmentType: 'نوع الموعد',
  startTime: 'وقت البداية',
  endTime: 'وقت النهاية',
  location: 'الموقع',
  notes: 'ملاحظات',
  appointmentDetails: 'تفاصيل الموعد',

  // Pending queue (Manager)
  pendingQueue: 'المواعيد المعلقة',

  // Errors
  conflictMinistry: 'يوجد تعارض مع إجتماع وزارة — لا يمكن الحجز في هذا الوقت',
  conflictWarning: 'يوجد تعارض مع مواعيد أخرى',
  conflictProceed: 'متابعة رغم التعارض',
  networkError: 'خطأ في الاتصال',
  genericError: 'حدث خطأ، حاول مرة أخرى',

  // Settings
  settings: 'الإعدادات',
  name: 'الاسم',
  role: 'الدور',
  coordinator: 'منسق',
  manager: 'مدير',
} as const;
