import { queryOptions, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../api";
import { useWorkspaceId } from "../hooks";
import { projectKeys } from "../projects/queries";
import type { CreateCompanyRequest, UpdateCompanyRequest } from "../types";

// Calm UI fork: companies group projects and pick the Claude profile.

export const companyKeys = {
  all: (wsId: string) => ["companies", wsId] as const,
  list: (wsId: string) => [...companyKeys.all(wsId), "list"] as const,
};

export function companyListOptions(wsId: string) {
  return queryOptions({
    queryKey: companyKeys.list(wsId),
    queryFn: () => api.listCompanies(),
    select: (data) => data.companies,
  });
}

function useInvalidateCompanies() {
  const qc = useQueryClient();
  const wsId = useWorkspaceId();
  return () => {
    qc.invalidateQueries({ queryKey: companyKeys.all(wsId) });
    qc.invalidateQueries({ queryKey: projectKeys.all(wsId) });
  };
}

export function useCreateCompany() {
  const invalidate = useInvalidateCompanies();
  return useMutation({
    mutationFn: (data: CreateCompanyRequest) => api.createCompany(data),
    onSettled: invalidate,
  });
}

export function useUpdateCompany() {
  const invalidate = useInvalidateCompanies();
  return useMutation({
    mutationFn: ({ id, ...data }: UpdateCompanyRequest & { id: string }) => api.updateCompany(id, data),
    onSettled: invalidate,
  });
}

export function useDeleteCompany() {
  const invalidate = useInvalidateCompanies();
  return useMutation({
    mutationFn: (id: string) => api.deleteCompany(id),
    onSettled: invalidate,
  });
}

export function useSetProjectCompany() {
  const invalidate = useInvalidateCompanies();
  return useMutation({
    mutationFn: ({ projectId, companyId }: { projectId: string; companyId: string | null }) =>
      api.setProjectCompany(projectId, companyId),
    onSettled: invalidate,
  });
}
