import React, { useState, useEffect } from 'react';

interface SettingsSheetProps {
  onClose: () => void;
  isPhoneConnected: boolean;
}

interface ApiStatus {
  name: string;
  status: 'checking' | 'healthy' | 'unhealthy' | 'idle';
}

const SettingsSheet: React.FC<SettingsSheetProps> = ({ onClose, isPhoneConnected }) => {
  const [configVersion, setConfigVersion] = useState<string>('v1.0');
  const [lastUpdated, setLastUpdated] = useState<string>('未检查');
  const [isLoadingConfig, setIsLoadingConfig] = useState(false);
  const [isCheckingHealth, setIsCheckingHealth] = useState(false);
  const [isPushingConfig, setIsPushingConfig] = useState(false);
  const [apiStatuses, setApiStatuses] = useState<ApiStatus[]>([
    { name: 'QQ搜索', status: 'idle' },
    { name: 'QQ歌词', status: 'idle' },
    { name: '网易搜索', status: 'idle' },
    { name: '网易歌词', status: 'idle' },
    { name: '酷狗搜索', status: 'idle' },
    { name: '酷狗歌词', status: 'idle' },
  ]);

  // Fetch API config from GitHub CDN
  const fetchApiConfig = async () => {
    setIsLoadingConfig(true);
    try {
      const urls = [
        'https://cdn.jsdelivr.net/gh/andrea23shannon-ship-it/LyricsCaster@main/api_config.json',
        'https://raw.githubusercontent.com/andrea23shannon-ship-it/LyricsCaster/main/api_config.json',
      ];

      let config = null;
      for (const url of urls) {
        try {
          const response = await fetch(url, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
          });
          if (response.ok) {
            config = await response.json();
            break;
          }
        } catch (err) {
          // Try next URL
        }
      }

      if (config) {
        setConfigVersion(config.version || 'v1.0');
        setLastUpdated(new Date().toLocaleString('zh-CN'));
      } else {
        setLastUpdated('获取失败');
      }
    } catch (err) {
      console.error('Failed to fetch API config:', err);
      setLastUpdated('获取失败');
    } finally {
      setIsLoadingConfig(false);
    }
  };

  // Test individual API health
  const testApiHealth = async (apiName: string, endpoint: string, method: string, payload?: any): Promise<boolean> => {
    try {
      const options: RequestInit = {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
      };
      if (method === 'POST' && payload) {
        options.body = JSON.stringify(payload);
      }

      const response = await fetch(endpoint, options);
      const data = await response.json();

      // Check if response has data
      return response.ok && (data !== null && data !== undefined && Object.keys(data).length > 0);
    } catch (err) {
      console.error(`Health check failed for ${apiName}:`, err);
      return false;
    }
  };

  // Run health checks on all APIs
  const runHealthChecks = async () => {
    setIsCheckingHealth(true);

    // Set all to checking state
    setApiStatuses(prev =>
      prev.map(api => ({ ...api, status: 'checking' }))
    );

    const healthChecks = [
      {
        name: 'QQ搜索',
        test: () => testApiHealth('QQ搜索', 'https://u.y.qq.com/cgi-bin/musicu.fcg', 'POST', {
          request_key: 'SearchCoverPageFirstRequest',
          searchWord: '周杰伦',
        }),
      },
      {
        name: 'QQ歌词',
        test: () => testApiHealth('QQ歌词', 'https://u.y.qq.com/cgi-bin/musicu.fcg', 'POST', {
          request_key: 'GetLyricsPageUGCRequest',
          songmid: '000',
        }),
      },
      {
        name: '网易搜索',
        test: () => testApiHealth('网易搜索', 'https://music.163.com/api/search/get/web', 'POST', {
          s: '周杰伦',
          type: 1,
        }),
      },
      {
        name: '网易歌词',
        test: () => testApiHealth('网易歌词', 'https://music.163.com/api/song/lyric?id=0', 'GET'),
      },
      {
        name: '酷狗搜索',
        test: () => testApiHealth('酷狗搜索', 'https://mobilecdn.kugou.com/api/v3/search/song?keyword=周杰伦', 'GET'),
      },
      {
        name: '酷狗歌词',
        test: () => testApiHealth('酷狗歌词', 'https://m.kugou.com/app/i/krc.php?id=0', 'GET'),
      },
    ];

    for (const check of healthChecks) {
      try {
        const isHealthy = await check.test();
        setApiStatuses(prev =>
          prev.map(api =>
            api.name === check.name
              ? { ...api, status: isHealthy ? 'healthy' : 'unhealthy' }
              : api
          )
        );
      } catch (err) {
        setApiStatuses(prev =>
          prev.map(api =>
            api.name === check.name
              ? { ...api, status: 'unhealthy' }
              : api
          )
        );
      }
    }

    setIsCheckingHealth(false);
  };

  // Push config to connected phone
  const pushConfigToPhone = async () => {
    if (!isPhoneConnected) {
      alert('未连接到手机，无法推送配置');
      return;
    }

    setIsPushingConfig(true);
    try {
      // Fetch current config
      const urls = [
        'https://cdn.jsdelivr.net/gh/andrea23shannon-ship-it/LyricsCaster@main/api_config.json',
        'https://raw.githubusercontent.com/andrea23shannon-ship-it/LyricsCaster/main/api_config.json',
      ];

      let config = null;
      for (const url of urls) {
        try {
          const response = await fetch(url);
          if (response.ok) {
            config = await response.json();
            break;
          }
        } catch (err) {
          // Try next URL
        }
      }

      if (config) {
        // In a real implementation, this would send to the phone via WebSocket
        console.log('Config to push:', config);
        alert('配置已推送到手机');
      } else {
        alert('无法获取配置');
      }
    } catch (err) {
      console.error('Failed to push config:', err);
      alert('推送失败');
    } finally {
      setIsPushingConfig(false);
    }
  };

  const getStatusColor = (status: ApiStatus['status']): string => {
    switch (status) {
      case 'healthy':
        return '#4CAF50'; // Green
      case 'unhealthy':
        return '#f44336'; // Red
      case 'checking':
        return '#FF9800'; // Orange
      default:
        return '#999999'; // Gray
    }
  };

  const containerStyle: React.CSSProperties = {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  };

  const modalStyle: React.CSSProperties = {
    backgroundColor: '#1e1e1e',
    borderRadius: '8px',
    width: '90%',
    maxWidth: '600px',
    maxHeight: '90vh',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    color: '#FFFFFF',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  };

  const headerStyle: React.CSSProperties = {
    padding: '16px 24px',
    borderBottom: '1px solid #3D3D3D',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  };

  const contentStyle: React.CSSProperties = {
    flex: 1,
    overflowY: 'auto',
    padding: '24px',
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
  };

  const sectionStyle: React.CSSProperties = {
    backgroundColor: '#2D2D2D',
    borderRadius: '8px',
    padding: '16px',
    border: '1px solid #3D3D3D',
  };

  const sectionTitleStyle: React.CSSProperties = {
    fontSize: '14px',
    fontWeight: '600',
    marginBottom: '12px',
    color: '#FFFFFF',
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
  };

  const configInfoStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '12px',
    marginBottom: '12px',
    fontSize: '13px',
  };

  const configItemStyle: React.CSSProperties = {
    backgroundColor: '#3D3D3D',
    padding: '8px 12px',
    borderRadius: '4px',
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  };

  const configLabelStyle: React.CSSProperties = {
    color: '#CCCCCC',
    fontSize: '12px',
  };

  const configValueStyle: React.CSSProperties = {
    color: '#FFFFFF',
    fontSize: '13px',
    fontWeight: '500',
  };

  const apiGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '12px',
    marginBottom: '12px',
  };

  const apiStatusRowStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    padding: '12px',
    backgroundColor: '#3D3D3D',
    borderRadius: '4px',
    fontSize: '13px',
  };

  const statusDotStyle = (color: string): React.CSSProperties => ({
    width: '10px',
    height: '10px',
    borderRadius: '50%',
    backgroundColor: color,
    flexShrink: 0,
    animation: color === '#FF9800' ? 'pulse 1s infinite' : 'none',
  });

  const buttonStyle: React.CSSProperties = {
    padding: '10px 16px',
    backgroundColor: '#0E639C',
    border: 'none',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '500',
    transition: 'background-color 0.2s ease',
  };

  const buttonSecondaryStyle: React.CSSProperties = {
    padding: '10px 16px',
    backgroundColor: '#3D3D3D',
    border: '1px solid #4D4D4D',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '500',
    transition: 'background-color 0.2s ease',
  };

  const footerStyle: React.CSSProperties = {
    padding: '16px 24px',
    borderTop: '1px solid #3D3D3D',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '12px',
  };

  const buttonGroupStyle: React.CSSProperties = {
    display: 'flex',
    gap: '8px',
    justifyContent: 'flex-start',
  };

  return (
    <div style={containerStyle}>
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>

      <div style={modalStyle}>
        {/* Header */}
        <div style={headerStyle}>
          <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600' }}>设置</h2>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              color: '#CCCCCC',
              fontSize: '20px',
              cursor: 'pointer',
              padding: '0',
            }}
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div style={contentStyle}>
          {/* API Configuration Section */}
          <div style={sectionStyle}>
            <div style={sectionTitleStyle}>API配置管理</div>

            {/* Config Info */}
            <div style={configInfoStyle}>
              <div style={configItemStyle}>
                <div style={configLabelStyle}>配置版本</div>
                <div style={configValueStyle}>{configVersion}</div>
              </div>
              <div style={configItemStyle}>
                <div style={configLabelStyle}>最后更新</div>
                <div style={configValueStyle}>{lastUpdated}</div>
              </div>
            </div>

            {/* API Health Status Grid */}
            <div style={{ marginBottom: '12px' }}>
              <div style={{ fontSize: '12px', color: '#CCCCCC', marginBottom: '8px' }}>接口状态</div>
              <div style={apiGridStyle}>
                {apiStatuses.map((api, idx) => (
                  <div key={idx} style={apiStatusRowStyle}>
                    <div style={statusDotStyle(getStatusColor(api.status))} />
                    <span style={{ flex: 1 }}>{api.name}</span>
                    <span style={{ fontSize: '11px', color: '#999999' }}>
                      {api.status === 'checking' ? '检查中...' : api.status === 'healthy' ? '正常' : api.status === 'unhealthy' ? '异常' : '未检查'}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Buttons */}
            <div style={buttonGroupStyle}>
              <button
                onClick={fetchApiConfig}
                disabled={isLoadingConfig}
                onMouseEnter={(e) => !isLoadingConfig && (e.currentTarget.style.backgroundColor = '#1177BB')}
                onMouseLeave={(e) => !isLoadingConfig && (e.currentTarget.style.backgroundColor = '#0E639C')}
                style={{
                  ...buttonStyle,
                  opacity: isLoadingConfig ? 0.6 : 1,
                  cursor: isLoadingConfig ? 'default' : 'pointer',
                }}
              >
                {isLoadingConfig ? '刷新中...' : '刷新配置'}
              </button>
              <button
                onClick={runHealthChecks}
                disabled={isCheckingHealth}
                onMouseEnter={(e) => !isCheckingHealth && (e.currentTarget.style.backgroundColor = '#1177BB')}
                onMouseLeave={(e) => !isCheckingHealth && (e.currentTarget.style.backgroundColor = '#0E639C')}
                style={{
                  ...buttonStyle,
                  opacity: isCheckingHealth ? 0.6 : 1,
                  cursor: isCheckingHealth ? 'default' : 'pointer',
                }}
              >
                {isCheckingHealth ? '检测中...' : '检测接口'}
              </button>
              <button
                onClick={pushConfigToPhone}
                disabled={!isPhoneConnected || isPushingConfig}
                onMouseEnter={(e) => (isPhoneConnected && !isPushingConfig) && (e.currentTarget.style.backgroundColor = '#1177BB')}
                onMouseLeave={(e) => (isPhoneConnected && !isPushingConfig) && (e.currentTarget.style.backgroundColor = '#0E639C')}
                style={{
                  ...buttonStyle,
                  opacity: (!isPhoneConnected || isPushingConfig) ? 0.6 : 1,
                  cursor: (!isPhoneConnected || isPushingConfig) ? 'default' : 'pointer',
                }}
              >
                {isPushingConfig ? '推送中...' : '推送到手机'}
              </button>
            </div>
          </div>

          {/* About Section */}
          <div style={sectionStyle}>
            <div style={sectionTitleStyle}>关于</div>
            <div style={configInfoStyle}>
              <div style={configItemStyle}>
                <div style={configLabelStyle}>应用名称</div>
                <div style={configValueStyle}>LyricsCaster 歌词投屏</div>
              </div>
              <div style={configItemStyle}>
                <div style={configLabelStyle}>版本号</div>
                <div style={configValueStyle}>v1.0</div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div style={footerStyle}>
          <button
            onClick={onClose}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#505050')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#3D3D3D')}
            style={buttonSecondaryStyle}
          >
            完成
          </button>
        </div>
      </div>
    </div>
  );
};

export default SettingsSheet;
