import { useStore } from "@/lib/store";

const levelStyles: Record<string, string> = {
  success: "bg-green-50 border-l-green-700 text-green-900",
  error: "bg-red-50 border-l-red-700 text-red-900",
  warning: "bg-amber-50 border-l-amber-700 text-amber-900",
  info: "bg-blue-50 border-l-blue-700 text-blue-900",
};

export function Toast() {
  const toast = useStore((s) => s.toast);
  const clearToast = useStore((s) => s.clearToast);

  if (!toast) return null;

  const style = levelStyles[toast.level] ?? levelStyles.info;

  return (
    <div
      className={`fixed bottom-6 right-6 border-l-4 px-4 py-3 rounded-md shadow-lg max-w-sm z-50 ${style}`}
    >
      <div className="flex justify-between items-start gap-2">
        <span className="text-sm font-medium">{toast.msg}</span>
        <button
          onClick={clearToast}
          className="text-current opacity-50 hover:opacity-100"
        >
          ×
        </button>
      </div>
      {toast.detail && (
        <p className="text-xs opacity-70 mt-1">{toast.detail}</p>
      )}
    </div>
  );
}
