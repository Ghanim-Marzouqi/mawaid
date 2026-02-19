class Strings {
  Strings._();

  // App
  static const appName = 'مواعيد';

  // Auth
  static const login = 'تسجيل الدخول';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const loginButton = 'دخول';
  static const loginError = 'البريد أو كلمة المرور غير صحيحة';

  // Appointment types
  static const ministry = 'إجتماع وزارة';
  static const patient = 'موعد مريض';
  static const external_ = 'موعد خارجي';

  // Statuses
  static const pending = 'بانتظار الموافقة';
  static const confirmed = 'مؤكد';
  static const rejected = 'مرفوض';
  static const suggested = 'مقترح وقت بديل';
  static const cancelled = 'ملغي';

  // Actions
  static const approve = 'موافقة';
  static const reject = 'رفض';
  static const suggestAlternative = 'اقتراح وقت بديل';
  static const acceptSuggestion = 'قبول الاقتراح';
  static const rejectSuggestion = 'رفض الاقتراح';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const create = 'إنشاء';
  static const delete = 'حذف';
  static const signOut = 'تسجيل الخروج';
  static const edit = 'تعديل';
  static const retry = 'إعادة المحاولة';
  static const confirm = 'تأكيد';
  static const proceed = 'متابعة';

  // Form fields
  static const title = 'العنوان';
  static const appointmentType = 'نوع الموعد';
  static const startTime = 'وقت البداية';
  static const endTime = 'وقت النهاية';
  static const location = 'الموقع';
  static const notes = 'ملاحظات';
  static const message = 'رسالة';
  static const newAppointment = 'موعد جديد';
  static const editAppointment = 'تعديل الموعد';
  static const appointmentDetails = 'تفاصيل الموعد';

  // Notifications
  static const notifications = 'الإشعارات';
  static const noNotifications = 'لا توجد إشعارات';

  // Calendar
  static const calendar = 'التقويم';
  static const today = 'اليوم';
  static const noAppointments = 'لا توجد مواعيد';

  // Dashboard
  static const dashboard = 'الرئيسية';
  static const pendingCount = 'بانتظار الموافقة';
  static const confirmedCount = 'مؤكدة';
  static const todaySchedule = 'جدول اليوم';

  // Manager
  static const pendingQueue = 'بانتظار';

  // Errors
  static const conflictMinistry =
      'يوجد تعارض مع إجتماع وزارة — لا يمكن الحجز في هذا الوقت';
  static const conflictWarning = 'يوجد تعارض مع مواعيد أخرى';
  static const conflictProceed = 'متابعة رغم التعارض';
  static const networkError = 'خطأ في الاتصال';
  static const genericError = 'حدث خطأ، حاول مرة أخرى';
  static const requiredField = 'هذا الحقل مطلوب';
  static const invalidEmail = 'البريد الإلكتروني غير صالح';
  static const passwordTooShort = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
  static const titleTooLong = 'العنوان يجب أن لا يتجاوز 200 حرف';
  static const locationTooLong = 'الموقع يجب أن لا يتجاوز 500 حرف';
  static const notesTooLong = 'الملاحظات يجب أن لا تتجاوز 1000 حرف';
  static const messageTooLong = 'الرسالة يجب أن لا تتجاوز 500 حرف';
  static const startMustBeBeforeEnd = 'وقت البداية يجب أن يكون قبل وقت النهاية';
  static const startMustBeFuture = 'وقت البداية يجب أن يكون في المستقبل';
  static const minDuration = 'مدة الموعد يجب أن لا تقل عن 15 دقيقة';
  static const notFound = 'الصفحة غير موجودة';
  static const goBack = 'العودة';

  // Settings
  static const settings = 'الإعدادات';
  static const name_ = 'الاسم';
  static const role = 'الدور';
  static const coordinatorRole = 'منسقة';
  static const managerRole = 'مدير';

  // Success messages
  static const appointmentCreated = 'تم إنشاء الموعد بنجاح';
  static const appointmentUpdated = 'تم تحديث الموعد بنجاح';
  static const appointmentApproved = 'تم تأكيد الموعد';
  static const appointmentRejected = 'تم رفض الموعد';
  static const appointmentCancelled = 'تم إلغاء الموعد';
  static const appointmentDeleted = 'تم حذف الموعد';
  static const suggestionSent = 'تم إرسال الاقتراح';
  static const suggestionAccepted = 'تم قبول الاقتراح';
  static const suggestionRejected = 'تم رفض الاقتراح';

  // Confirmation dialogs
  static const confirmApprove = 'هل تريد تأكيد هذا الموعد؟';
  static const confirmReject = 'هل تريد رفض هذا الموعد؟';
  static const confirmCancel = 'هل تريد إلغاء هذا الموعد؟';
  static const confirmDelete = 'هل تريد حذف هذا الموعد؟';
  static const confirmAcceptSuggestion = 'هل تريد قبول الوقت البديل المقترح؟';
  static const confirmRejectSuggestion = 'هل تريد رفض الوقت البديل المقترح؟';
  static const confirmSignOut = 'هل تريد تسجيل الخروج؟';
}
