export function BrandMark({ size = 30 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      fill="none"
      aria-hidden
      className="brand-mark"
    >
      <rect width="64" height="64" rx="16" fill="currentColor" opacity="0.14" />
      <path
        d="M17 45V27l15-9 15 9v18"
        stroke="currentColor"
        strokeWidth="4"
        strokeLinejoin="round"
      />
      <path
        d="M26 45V33h12v12"
        stroke="#f5b942"
        strokeWidth="4"
        strokeLinejoin="round"
      />
      <circle cx="32" cy="16.5" r="3.2" fill="#f5b942" />
    </svg>
  );
}
