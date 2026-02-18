import { useState, useCallback } from 'react';
import { supabase } from '@/services/supabase';
import type { AppointmentType, AppointmentStatus } from '@/types/database';

export interface ConflictResult {
  id: string;
  title: string;
  type: AppointmentType;
  status: AppointmentStatus;
  start_time: string;
  end_time: string;
}

interface ConflictCheckResult {
  hasMinistryConflict: boolean;
  hasWarningConflict: boolean;
  conflicts: ConflictResult[];
}

export function useConflictCheck() {
  const [isChecking, setIsChecking] = useState(false);

  const checkConflicts = useCallback(
    async (
      startTime: string,
      endTime: string,
      excludeId?: string | null
    ): Promise<ConflictCheckResult> => {
      setIsChecking(true);
      try {
        const { data, error } = await supabase.rpc(
          'check_appointment_overlap',
          {
            p_start_time: startTime,
            p_end_time: endTime,
            p_exclude_id: excludeId ?? null,
          }
        );

        const conflicts = (data as ConflictResult[] | null) ?? [];

        if (error || conflicts.length === 0) {
          return { hasMinistryConflict: false, hasWarningConflict: false, conflicts: [] };
        }

        const hasMinistryConflict = conflicts.some(
          (c) => c.type === 'ministry' && c.status === 'confirmed'
        );
        const hasWarningConflict = !hasMinistryConflict && conflicts.length > 0;

        return { hasMinistryConflict, hasWarningConflict, conflicts };
      } finally {
        setIsChecking(false);
      }
    },
    []
  );

  return { checkConflicts, isChecking };
}
