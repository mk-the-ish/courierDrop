import React from 'react';

interface HandshakeIconProps {
  size?: number;
  className?: string;
  active?: boolean;
}

export default function HandshakeIcon({ size = 24, className = '', active = true }: HandshakeIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={`${className} ${active ? 'text-transit-teal' : 'text-gray-400'}`}
    >
      {/* Left hand */}
      <path d="M11 14l2 2m-2-2l-2-2m2 2v5m0-5h3a2 2 0 0 1 2 2v2" />
      {/* Right hand */}
      <path d="M13 14l-2 2m2-2l2-2m-2 2v5m0-5H10a2 2 0 0 0-2 2v2" />
      {/* Shield background */}
      <path d="M12 2l-8 4v6c0 6 8 8 8 8s8-2 8-8V6l-8-4z" />
      {/* Connection indicator */}
      {active && (
        <>
          <circle cx="12" cy="12" r="1.5" fill="currentColor" />
          <circle cx="12" cy="12" r="3" fill="none" opacity="0.5" />
        </>
      )}
    </svg>
  );
}
