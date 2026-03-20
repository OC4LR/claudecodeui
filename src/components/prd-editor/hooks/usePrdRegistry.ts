import { useCallback, useEffect, useState } from 'react';
import type { ExistingPrdFile } from '../types';

type UsePrdRegistryResult = {
  existingPrds: ExistingPrdFile[];
  refreshExistingPrds: () => Promise<void>;
};

export function usePrdRegistry(projectName?: string): UsePrdRegistryResult {
  const [existingPrds, setExistingPrds] = useState<ExistingPrdFile[]>([]);

  const refreshExistingPrds = useCallback(async () => {
    // PRD registry functionality has been disabled
    // The backend API endpoint was removed as part of TaskMaster cleanup
    setExistingPrds([]);
  }, []);

  useEffect(() => {
    void refreshExistingPrds();
  }, [refreshExistingPrds]);

  return {
    existingPrds,
    refreshExistingPrds,
  };
}
