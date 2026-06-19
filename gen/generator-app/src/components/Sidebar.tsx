import React from 'react';
import { type SchedulerConfig, type CoreTypeConfig } from '../utils/rtlGenerator';

interface SidebarProps {
  config: SchedulerConfig;
  onChange: (newConfig: SchedulerConfig) => void;
}

const COLOR_PALETTE = [
  'var(--primary-orange)', // Orange
  '#007aff',               // Blue
  '#34c759',               // Green
  '#af52de',               // Purple
  '#ff9500',               // Gold
  '#5856d6',               // Indigo
  '#ff2d55',               // Pink
];

export const Sidebar: React.FC<SidebarProps> = ({ config, onChange }) => {
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const updateParam = (key: keyof Omit<SchedulerConfig, 'coresList'>, val: number) => {
    onChange({
      ...config,
      [key]: val,
    });
  };

  // Validation function for SchedulerConfig schema
  const validateConfig = (data: any): data is SchedulerConfig => {
    if (!data || typeof data !== 'object') return false;

    const requiredParams = [
      'decodeWidth',
      'phyRegs',
      'robEntries',
      'coresList',
      'prmUpdate',
      'prmBuffer',
      'unallocatePhyreg',
      'flowWindows'
    ];

    for (const param of requiredParams) {
      if (!(param in data)) return false;
      if (param !== 'coresList' && typeof data[param] !== 'number') return false;
    }

    if (!Array.isArray(data.coresList)) return false;

    for (const core of data.coresList) {
      if (!core || typeof core !== 'object') return false;
      if (
        typeof core.id !== 'string' ||
        typeof core.name !== 'string' ||
        typeof core.count !== 'number' ||
        typeof core.stroke !== 'string'
      ) {
        return false;
      }
    }

    return true;
  };

  // Export current config as JSON file
  const handleExportJSON = () => {
    const dataStr = JSON.stringify(config, null, 2);
    const blob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'eulsukdo_config.json';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  // Trigger file selection for importing
  const handleTriggerImport = () => {
    fileInputRef.current?.click();
  };

  // Handle uploaded JSON file configuration mapping
  const handleImportJSON = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const parsed = JSON.parse(event.target?.result as string);
        if (validateConfig(parsed)) {
          onChange(parsed);
        } else {
          alert('Invalid configuration format. Please upload a valid EULSUKDO configuration file.');
        }
      } catch (err) {
        alert('Failed to parse JSON file. Ensure it is a valid JSON document.');
      }
    };
    reader.readAsText(file);
    e.target.value = ''; // Reset file input
  };

  // Add a new core type dynamically
  const handleAddCore = () => {
    const nextColor = COLOR_PALETTE[config.coresList.length % COLOR_PALETTE.length];
    const newCore: CoreTypeConfig = {
      id: `core-${Date.now()}`,
      name: `EX_PATH_${config.coresList.length + 1}`,
      count: 1,
      stroke: nextColor,
    };
    onChange({
      ...config,
      coresList: [...config.coresList, newCore],
    });
  };

  // Delete a core type
  const handleRemoveCore = (id: string) => {
    if (config.coresList.length <= 1) return; // Must have at least 1 core type
    onChange({
      ...config,
      coresList: config.coresList.filter(c => c.id !== id),
    });
  };

  // Update fields inside a core type
  const handleUpdateCore = (id: string, key: keyof Omit<CoreTypeConfig, 'id' | 'stroke'>, val: string | number) => {
    onChange({
      ...config,
      coresList: config.coresList.map(c => {
        if (c.id === id) {
          return {
            ...c,
            [key]: val,
          };
        }
        return c;
      }),
    });
  };

  // Reorder cores (up/down)
  const handleMoveCore = (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= config.coresList.length) return;

    const newCores = [...config.coresList];
    const temp = newCores[index];
    newCores[index] = newCores[targetIndex];
    newCores[targetIndex] = temp;

    onChange({
      ...config,
      coresList: newCores,
    });
  };

  return (
    <div className="panel sidebar">
      <div className="panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2 className="panel-title">Configuration</h2>
        <div style={{ display: 'flex', gap: '6px' }}>
          <button 
            className="btn" 
            style={{ padding: '2px 8px', fontSize: '10px', borderColor: '#444', color: '#ccc' }} 
            onClick={handleExportJSON}
            title="Export parameters to JSON file"
          >
            Export
          </button>
          <button 
            className="btn" 
            style={{ padding: '2px 8px', fontSize: '10px', borderColor: '#444', color: '#ccc' }} 
            onClick={handleTriggerImport}
            title="Import parameters from JSON file"
          >
            Import
          </button>
          <input 
            type="file" 
            ref={fileInputRef} 
            style={{ display: 'none' }} 
            accept=".json" 
            onChange={handleImportJSON} 
          />
        </div>
      </div>
      <div className="sidebar-content">
        
        {/* Decode Width */}
        <div className="form-group">
          <label className="form-label">
            <span>Decode Width</span>
            <span className="form-value">{config.decodeWidth} slots</span>
          </label>
          <input
            type="number"
            min="1"
            max="8"
            step="1"
            value={config.decodeWidth}
            onChange={(e) => updateParam('decodeWidth', isNaN(parseInt(e.target.value)) ? 0 : parseInt(e.target.value))}
          />
          <p className="slider-description">
            한 사이클에 인출/디코드하여 스케줄러 큐에 전달할 명령어 슬롯 수입니다.
          </p>
        </div>

        {/* Physical Registers */}
        <div className="form-group">
          <label className="form-label">
            <span>Physical Registers (PRF)</span>
            <span className="form-value">{config.phyRegs} registers</span>
          </label>
          <input
            type="number"
            min="16"
            max="128"
            step="8"
            value={config.phyRegs}
            onChange={(e) => updateParam('phyRegs', isNaN(parseInt(e.target.value)) ? 0 : parseInt(e.target.value))}
          />
          <p className="slider-description">
            물리 레지스터(PRF) 개수입니다. 리셋 시 1사이클 비트맵 할당기로 즉각 리셋 및 동작 세팅됩니다.
          </p>
        </div>

        {/* ROB Entries */}
        <div className="form-group">
          <label className="form-label">
            <span>Instruction Entries (ROB)</span>
            <span className="form-value">{config.robEntries} entries</span>
          </label>
          <input
            type="number"
            min="16"
            max="256"
            step="16"
            value={config.robEntries}
            onChange={(e) => updateParam('robEntries', isNaN(parseInt(e.target.value)) ? 0 : parseInt(e.target.value))}
          />
          <p className="slider-description">
            비순차 완료 정렬을 위한 내부 ROB 버퍼 엔트리 개수입니다.
          </p>
        </div>

        <div style={{ height: '1px', backgroundColor: '#2c2c2c', margin: '4px 0' }} />

        {/* DYNAMIC EXECUTION PATHS SECTION */}
        <div style={{ display: 'flex', justifyContent: 'between', alignItems: 'center' }}>
          <span style={{ fontSize: '11px', fontWeight: 'bold', textTransform: 'uppercase', color: '#999' }}>Execution Cores</span>
        </div>

        {config.coresList.map((core, index) => (
          <div key={core.id} className="form-group" style={{ border: '1px solid #222', padding: '12px', background: '#121212', borderRadius: '2px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span style={{ fontSize: '11px', color: core.stroke, fontWeight: 'bold' }}>EX PATH #{index + 1}</span>
                <div style={{ display: 'flex', gap: '2px' }}>
                  {index > 0 && (
                    <button 
                      className="btn" 
                      style={{ padding: '1px 4px', fontSize: '8px', borderColor: '#333', color: '#aaa', minWidth: '15px', height: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center' }} 
                      onClick={() => handleMoveCore(index, 'up')}
                      title="Move Up"
                    >
                      ▲
                    </button>
                  )}
                  {index < config.coresList.length - 1 && (
                    <button 
                      className="btn" 
                      style={{ padding: '1px 4px', fontSize: '8px', borderColor: '#333', color: '#aaa', minWidth: '15px', height: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center' }} 
                      onClick={() => handleMoveCore(index, 'down')}
                      title="Move Down"
                    >
                      ▼
                    </button>
                  )}
                </div>
              </div>
              {config.coresList.length > 1 && (
                <button 
                  className="btn" 
                  style={{ padding: '2px 8px', fontSize: '9px', borderColor: '#444', color: '#888' }} 
                  onClick={() => handleRemoveCore(core.id)}
                >
                  Delete
                </button>
              )}
            </div>

            {/* Core Name */}
            <div className="form-group">
              <label style={{ fontSize: '10px', color: '#888' }}>Core Type Name</label>
              <input
                type="text"
                style={{
                  backgroundColor: '#1a1a1a',
                  border: '1px solid var(--border-color)',
                  color: 'var(--text-main)',
                  padding: '4px 8px',
                  fontSize: '11px',
                  outline: 'none',
                  borderRadius: '2px'
                }}
                value={core.name}
                onChange={(e) => handleUpdateCore(core.id, 'name', e.target.value)}
              />
            </div>

            {/* Core Count */}
            <div className="form-group">
              <label style={{ fontSize: '10px', color: '#888' }}>Instance Count</label>
              <input
                type="number"
                min="1"
                max="8"
                style={{
                  backgroundColor: '#1a1a1a',
                  border: '1px solid var(--border-color)',
                  color: 'var(--text-main)',
                  padding: '4px 8px',
                  fontSize: '11px',
                  outline: 'none',
                  borderRadius: '2px'
                }}
                value={core.count}
                onChange={(e) => handleUpdateCore(core.id, 'count', isNaN(parseInt(e.target.value)) ? 0 : parseInt(e.target.value))}
              />
            </div>
          </div>
        ))}

        <button 
          className="btn btn-primary" 
          style={{ width: '100%', padding: '8px', fontSize: '11px', marginTop: '4px' }} 
          onClick={handleAddCore}
        >
          + Add Core Type
        </button>

      </div>
    </div>
  );
};
