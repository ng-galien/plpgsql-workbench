const formatters = new Map<string, Intl.NumberFormat>();

function getFormatter(currency: string): Intl.NumberFormat {
  if (!formatters.has(currency)) {
    formatters.set(
      currency,
      new Intl.NumberFormat("fr-FR", {
        style: "currency",
        currency,
        minimumFractionDigits: 2,
      })
    );
  }
  return formatters.get(currency)!;
}

export function Currency({
  amount,
  currency = "EUR",
}: {
  amount: number;
  currency?: string;
}) {
  const formatted = getFormatter(currency).format(amount);
  const isNegative = amount < 0;

  return (
    <span
      className={`tabular-nums text-right ${
        isNegative ? "text-destructive" : ""
      }`}
    >
      {formatted}
    </span>
  );
}
