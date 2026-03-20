import { useEffect, useState, useRef } from 'react';
import mermaid from 'mermaid';

type MermaidRendererProps = {
  code: string;
};

// Generate unique ID for each mermaid diagram
let mermaidIdCounter = 0;

export function MermaidRenderer({ code }: MermaidRendererProps) {
  const [svg, setSvg] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const idRef = useRef(`mermaid-${++mermaidIdCounter}`);

  useEffect(() => {
    let isMounted = true;

    const renderMermaid = async () => {
      setIsLoading(true);
      setError(null);

      try {
        // Initialize mermaid with dark mode support
        mermaid.initialize({
          startOnLoad: false,
          theme: document.documentElement.classList.contains('dark') ? 'dark' : 'default',
          securityLevel: 'loose',
          fontFamily: 'ui-sans-serif, system-ui, sans-serif',
        });

        const { svg: renderedSvg } = await mermaid.render(idRef.current, code.trim());

        if (isMounted) {
          setSvg(renderedSvg);
          setError(null);
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : 'Failed to render mermaid diagram');
          setSvg('');
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    renderMermaid();

    return () => {
      isMounted = false;
    };
  }, [code]);

  if (isLoading) {
    return (
      <div className="my-2 flex items-center justify-center rounded-lg border border-gray-200 bg-gray-50 p-8 dark:border-gray-700 dark:bg-gray-800/50">
        <div className="text-sm text-gray-500 dark:text-gray-400">Rendering diagram...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="my-2 rounded-lg border border-red-200 bg-red-50 p-4 dark:border-red-800 dark:bg-red-900/20">
        <div className="mb-2 text-sm font-medium text-red-700 dark:text-red-400">Mermaid Syntax Error</div>
        <pre className="overflow-x-auto text-xs text-red-600 dark:text-red-300">{error}</pre>
        <pre className="mt-2 overflow-x-auto rounded bg-red-100 p-2 text-xs text-red-800 dark:bg-red-900/40 dark:text-red-200">{code}</pre>
      </div>
    );
  }

  return (
    <div
      className="my-2 overflow-x-auto rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-900"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}

export default MermaidRenderer;
