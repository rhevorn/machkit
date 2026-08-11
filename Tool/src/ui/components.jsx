import React from "react";
import { CopySimple } from "@phosphor-icons/react";
import "./ui.css";

export function SegmentedControl({ value, options, onChange, label }) {
  return (
    <div className="segmented" role="radiogroup" aria-label={label}>
      {options.map((option) => (
        <button
          className={value === option.value ? "is-selected" : ""}
          key={option.value}
          type="button"
          role="radio"
          aria-checked={value === option.value}
          onClick={() => onChange(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

export function Card({ title, icon: Icon, children }) {
  return (
    <section className="sift-card">
      <header className="card-title">
        {Icon ? <Icon size={17} weight="regular" aria-hidden="true" /> : null}
        <h2>{title}</h2>
      </header>
      {children}
    </section>
  );
}

export function Result({ value, placeholder, onCopy, copyLabel }) {
  return (
    <div className={`result ${value ? "" : "is-placeholder"}`}>
      <output>{value || placeholder || "—"}</output>
      {value ? (
        <button className="icon-button" type="button" onClick={() => onCopy(value)} aria-label={copyLabel} title={copyLabel}>
          <CopySimple size={16} aria-hidden="true" />
        </button>
      ) : null}
    </div>
  );
}

export function IconButton({ label, children, ...props }) {
  return (
    <button className="icon-button" type="button" aria-label={label} title={label} {...props}>
      {children}
    </button>
  );
}
