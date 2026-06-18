import { useState } from 'react';
import { Sidebar } from './components/Sidebar';
import { Visualizer } from './components/Visualizer';
import { CodePreview } from './components/CodePreview';
import { type SchedulerConfig, generateRTL } from './utils/rtlGenerator';

function App() {
  const [config, setConfig] = useState<SchedulerConfig>({
    decodeWidth: 2,
    phyRegs: 64,
    robEntries: 128,
    coresList: [
      { id: '1', name: 'Branch', count: 1, stroke: '#ff5500' },
      { id: '2', name: 'ALU', count: 3, stroke: '#00ccff' },
      { id: '3', name: 'Memory', count: 1, stroke: '#ffcc00' }
    ],
    prmUpdate: 3,
    prmBuffer: 4,
    unallocatePhyreg: 4,
    flowWindows: 8,
  });

  const generatedCode = generateRTL(config);

  return (
    <>
      {/* SoundCloud Styled Top Header */}
      <header className="app-header">
        <div className="logo-container">
          <div className="sc-orange-bar" />
          <h1 className="app-title">EULSUKDO CORE CAD</h1>
        </div>
        <div className="app-subtitle">
          Interactive Parameterized OO0 Hardware Generator
        </div>
      </header>

      {/* Main Layout containing Sidebar, Visualizer Canvas and Code preview */}
      <main className="app-body">
        {/* Left Side: Parameters Slider Panel */}
        <Sidebar config={config} onChange={setConfig} />

        {/* Center: Dynamic Hardware Pipeline SVG Visualizer */}
        <Visualizer config={config} />

        {/* Right Side: Code Preview and file download triggers */}
        <CodePreview code={generatedCode} />
      </main>
    </>
  );
}

export default App;
