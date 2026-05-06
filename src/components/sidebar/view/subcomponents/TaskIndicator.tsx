interface TaskIndicatorProps {
  status?: string;
  size?: string;
  className?: string;
}

export default function TaskIndicator({ className }: TaskIndicatorProps) {
  return <span className={className} />;
}
