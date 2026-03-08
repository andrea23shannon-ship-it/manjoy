import React, { useState, useEffect } from 'react';
import { LyricsStyle, hexToColor, colorToHex, FontWeight, TextAlignmentType, AnimationStyleType } from '../../shared/types';

interface StyleEditorViewProps {
  style: LyricsStyle;
  onStyleChange: (style: LyricsStyle) => void;
  onClose: () => void;
}

// Internal editor style format using hex colors (for HTML color pickers)
interface EditorStyle {
  fontName: string;
  fontSize: number;
  fontWeight: string;
  currentLineColor: string;
  currentLineGlow: boolean;
  otherLineColor: string;
  pastLineColor: string;
  backgroundColor: string;
  backgroundOpacity: number;
  backgroundImage: string;
  animationStyle: string;
  animationSpeed: number;
  alignment: string;
  lineSpacing: number;
  showTranslation: boolean;
  visibleLineCount: number;
  padding: number;
}

// Convert LyricsStyle (with CodableColor) to EditorStyle (with hex strings)
function styleToEditor(style: LyricsStyle): EditorStyle {
  return {
    fontName: style.fontName,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    currentLineColor: colorToHex(style.currentLineColor),
    currentLineGlow: style.currentLineGlow,
    otherLineColor: colorToHex(style.otherLineColor),
    pastLineColor: colorToHex(style.pastLineColor),
    backgroundColor: colorToHex(style.backgroundColor),
    backgroundOpacity: style.backgroundOpacity,
    backgroundImage: style.backgroundImage || '',
    animationStyle: style.animationStyle,
    animationSpeed: style.animationSpeed,
    alignment: style.alignment,
    lineSpacing: style.lineSpacing,
    showTranslation: style.showTranslation,
    visibleLineCount: style.visibleLineCount,
    padding: style.padding,
  };
}

// Convert EditorStyle (with hex strings) to LyricsStyle (with CodableColor)
function editorToStyle(editor: EditorStyle): LyricsStyle {
  return {
    fontName: editor.fontName,
    fontSize: editor.fontSize,
    fontWeight: editor.fontWeight as FontWeight,
    currentLineColor: hexToColor(editor.currentLineColor),
    currentLineGlow: editor.currentLineGlow,
    otherLineColor: hexToColor(editor.otherLineColor),
    pastLineColor: hexToColor(editor.pastLineColor),
    backgroundColor: hexToColor(editor.backgroundColor),
    backgroundOpacity: editor.backgroundOpacity,
    backgroundImage: editor.backgroundImage || undefined,
    animationStyle: editor.animationStyle as AnimationStyleType,
    animationSpeed: editor.animationSpeed,
    alignment: editor.alignment as TextAlignmentType,
    lineSpacing: editor.lineSpacing,
    showTranslation: editor.showTranslation,
    visibleLineCount: editor.visibleLineCount,
    padding: editor.padding,
  };
}

const SAMPLE_LYRICS = [
  '让我们荡起双桨',
  '小船儿推开波浪',
  '海面倒映着美丽的白塔',
  '四周环绕着绿树红墙'
];

const ANIMATION_OPTIONS = [
  { key: 'none', label: '无动画' },
  { key: 'smooth', label: '平滑滚动' },
  { key: 'fade', label: '淡入淡出' },
  { key: 'scale', label: '缩放高亮' },
  { key: 'karaoke', label: '卡拉OK逐字' },
  { key: 'bounce', label: '弹跳节拍' },
  { key: 'wave', label: '波浪律动' },
  { key: 'pulse', label: '脉冲呼吸' },
  { key: 'typewriter', label: '打字机' },
  { key: 'slideIn', label: '滑入聚焦' },
  { key: 'charBounce', label: '逐字弹入' },
  { key: 'scatter', label: '散落歌词' },
  { key: 'float3D', label: '3D浮现' },
  { key: 'randomSize', label: '随机大小' }
];

const THEME_PRESETS: Array<{ name: string; style: LyricsStyle }> = [
  {
    name: '经典金色',
    style: {
      fontName: 'Microsoft YaHei',
      fontSize: 48,
      fontWeight: FontWeight.Bold,
      currentLineColor: { r: 1, g: 0.843, b: 0, a: 1 }, // #FFD700
      currentLineGlow: true,
      otherLineColor: { r: 0.8, g: 0.8, b: 0.8, a: 1 }, // #CCCCCC
      pastLineColor: { r: 0.533, g: 0.533, b: 0.533, a: 1 }, // #888888
      backgroundColor: { r: 0, g: 0, b: 0, a: 1 }, // #000000
      backgroundOpacity: 0.8,
      animationStyle: AnimationStyleType.Smooth,
      animationSpeed: 0.5,
      alignment: TextAlignmentType.Center,
      lineSpacing: 20,
      showTranslation: false,
      visibleLineCount: 4,
      padding: 20
    }
  },
  {
    name: '冰蓝',
    style: {
      fontName: 'Microsoft YaHei',
      fontSize: 48,
      fontWeight: FontWeight.Semibold,
      currentLineColor: { r: 0, g: 1, b: 1, a: 1 }, // #00FFFF
      currentLineGlow: true,
      otherLineColor: { r: 0.267, g: 0.6, b: 1, a: 1 }, // #4499FF
      pastLineColor: { r: 0.133, g: 0.267, b: 0.667, a: 1 }, // #2244AA
      backgroundColor: { r: 0, g: 0.102, b: 0.302, a: 1 }, // #001A4D
      backgroundOpacity: 0.85,
      animationStyle: AnimationStyleType.Fade,
      animationSpeed: 0.6,
      alignment: TextAlignmentType.Center,
      lineSpacing: 22,
      showTranslation: false,
      visibleLineCount: 4,
      padding: 25
    }
  },
  {
    name: '暖阳',
    style: {
      fontName: 'Microsoft YaHei',
      fontSize: 48,
      fontWeight: FontWeight.Bold,
      currentLineColor: { r: 1, g: 0.549, b: 0, a: 1 }, // #FF8C00
      currentLineGlow: false,
      otherLineColor: { r: 1, g: 0.667, b: 0.267, a: 1 }, // #FFAA44
      pastLineColor: { r: 0.733, g: 0.4, b: 0.2, a: 1 }, // #BB6633
      backgroundColor: { r: 0.239, g: 0.157, b: 0.094, a: 1 }, // #3D2817
      backgroundOpacity: 0.8,
      animationStyle: AnimationStyleType.Smooth,
      animationSpeed: 0.5,
      alignment: TextAlignmentType.Center,
      lineSpacing: 20,
      showTranslation: false,
      visibleLineCount: 4,
      padding: 20
    }
  },
  {
    name: '清新绿',
    style: {
      fontName: 'Microsoft YaHei',
      fontSize: 48,
      fontWeight: FontWeight.Medium,
      currentLineColor: { r: 0, g: 0.867, b: 0.4, a: 1 }, // #00DD66
      currentLineGlow: true,
      otherLineColor: { r: 0.267, g: 1, b: 0.533, a: 1 }, // #44FF88
      pastLineColor: { r: 0.133, g: 0.6, b: 0.4, a: 1 }, // #229966
      backgroundColor: { r: 0.102, g: 0.2, b: 0.102, a: 1 }, // #1A331A
      backgroundOpacity: 0.8,
      animationStyle: AnimationStyleType.Wave,
      animationSpeed: 0.55,
      alignment: TextAlignmentType.Center,
      lineSpacing: 21,
      showTranslation: false,
      visibleLineCount: 4,
      padding: 22
    }
  },
  {
    name: '粉色梦幻',
    style: {
      fontName: 'Microsoft YaHei',
      fontSize: 48,
      fontWeight: FontWeight.Semibold,
      currentLineColor: { r: 1, g: 0.412, b: 0.706, a: 1 }, // #FF69B4
      currentLineGlow: true,
      otherLineColor: { r: 1, g: 0.714, b: 0.851, a: 1 }, // #FFB6D9
      pastLineColor: { r: 0.867, g: 0.4, b: 0.6, a: 1 }, // #DD6699
      backgroundColor: { r: 0.2, g: 0.067, b: 0.133, a: 1 }, // #331122
      backgroundOpacity: 0.85,
      animationStyle: AnimationStyleType.Pulse,
      animationSpeed: 0.5,
      alignment: TextAlignmentType.Center,
      lineSpacing: 23,
      showTranslation: false,
      visibleLineCount: 4,
      padding: 24
    }
  }
];

const StyleEditorView: React.FC<StyleEditorViewProps> = ({
  style,
  onStyleChange,
  onClose
}) => {
  const [previewLineIndex, setPreviewLineIndex] = useState(0);
  const [localStyle, setLocalStyle] = useState<EditorStyle>(() => styleToEditor(style));
  const [importedFonts, setImportedFonts] = useState<string[]>([]);
  const [backgroundImagePreview, setBackgroundImagePreview] = useState<string>('');

  useEffect(() => {
    const interval = setInterval(() => {
      setPreviewLineIndex((prev) => (prev + 1) % SAMPLE_LYRICS.length);
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  // Load imported fonts on mount
  useEffect(() => {
    const loadFonts = async () => {
      try {
        const fonts = await (window as any).electronAPI.getFonts();
        setImportedFonts(fonts || []);
      } catch (error) {
        console.error('Failed to load fonts:', error);
      }
    };
    loadFonts();
  }, []);

  const handleStyleChange = (updates: Partial<EditorStyle>) => {
    const newEditorStyle = { ...localStyle, ...updates };
    setLocalStyle(newEditorStyle);
    // Convert to LyricsStyle before calling the callback
    onStyleChange(editorToStyle(newEditorStyle));
  };

  const handleApplyPreset = (preset: typeof THEME_PRESETS[0]) => {
    const editorStyle = styleToEditor(preset.style);
    setLocalStyle(editorStyle);
    onStyleChange(preset.style);
  };

  const handleImportFont = async () => {
    try {
      const result = await (window as any).electronAPI.openFileDialog({ type: 'font' });
      if (result && result.filePaths && result.filePaths[0]) {
        const filePath = result.filePaths[0];
        const fileName = filePath.split(/[\\/]/).pop()?.replace(/\.(ttf|otf)$/i, '') || 'Unknown Font';

        const success = await (window as any).electronAPI.importFont(filePath, fileName);
        if (success) {
          setImportedFonts([...importedFonts, fileName]);
        }
      }
    } catch (error) {
      console.error('Failed to import font:', error);
    }
  };

  const handleRemoveFont = async (fontName: string) => {
    try {
      const success = await (window as any).electronAPI.removeFont(fontName);
      if (success) {
        setImportedFonts(importedFonts.filter((f) => f !== fontName));
      }
    } catch (error) {
      console.error('Failed to remove font:', error);
    }
  };

  const handleSelectBackgroundImage = async () => {
    try {
      const result = await (window as any).electronAPI.openFileDialog({ type: 'image' });
      if (result && result.filePaths && result.filePaths[0]) {
        const filePath = result.filePaths[0];
        handleStyleChange({ backgroundImage: filePath });
        setBackgroundImagePreview(filePath);
      }
    } catch (error) {
      console.error('Failed to select background image:', error);
    }
  };

  const handleRemoveBackgroundImage = () => {
    handleStyleChange({ backgroundImage: '' });
    setBackgroundImagePreview('');
  };

  const containerStyle: React.CSSProperties = {
    display: 'flex',
    flexDirection: 'column',
    height: '100vh',
    backgroundColor: '#1E1E1E',
    color: '#FFFFFF',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    fontSize: '14px'
  };

  const contentStyle: React.CSSProperties = {
    flex: 1,
    overflowY: 'auto',
    padding: '24px',
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: '24px'
  };

  const sectionStyle: React.CSSProperties = {
    backgroundColor: '#2D2D2D',
    borderRadius: '8px',
    padding: '16px',
    border: '1px solid #3D3D3D'
  };

  const sectionTitleStyle: React.CSSProperties = {
    fontSize: '14px',
    fontWeight: '600',
    marginBottom: '12px',
    color: '#FFFFFF',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  };

  const labelStyle: React.CSSProperties = {
    fontSize: '13px',
    marginBottom: '6px',
    color: '#CCCCCC',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center'
  };

  const inputStyle: React.CSSProperties = {
    width: '100%',
    padding: '8px 12px',
    backgroundColor: '#3D3D3D',
    border: '1px solid #4D4D4D',
    borderRadius: '4px',
    color: '#FFFFFF',
    fontSize: '13px',
    marginBottom: '12px',
    boxSizing: 'border-box'
  };

  const sliderStyle: React.CSSProperties = {
    width: '100%',
    marginBottom: '12px',
    height: '4px',
    cursor: 'pointer'
  };

  const colorPickerContainerStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '12px'
  };

  const colorPickerStyle: React.CSSProperties = {
    width: '40px',
    height: '40px',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  };

  const previewStyle: React.CSSProperties = {
    gridColumn: '1 / -1',
    backgroundColor: localStyle.backgroundColor || '#000000',
    borderRadius: '8px',
    padding: `${localStyle.padding || 20}px`,
    minHeight: '200px',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '12px',
    opacity: localStyle.backgroundOpacity || 0.8
  };

  const previewLineStyle = (index: number): React.CSSProperties => {
    const isCurrentLine = index === previewLineIndex;
    const color = isCurrentLine ? localStyle.currentLineColor : localStyle.otherLineColor;
    const textShadow = isCurrentLine && localStyle.currentLineGlow
      ? `0 0 10px ${localStyle.currentLineColor}, 0 0 20px ${localStyle.currentLineColor}`
      : 'none';

    // Map TextAlignmentType to CSS textAlign
    const alignmentMap: Record<string, any> = {
      'leading': 'left',
      'center': 'center',
      'trailing': 'right'
    };

    return {
      color: color,
      fontSize: `${localStyle.fontSize || 24}px`,
      fontWeight: localStyle.fontWeight as any || 'normal',
      textAlign: alignmentMap[localStyle.alignment || 'center'],
      textShadow: textShadow,
      transition: 'all 0.3s ease',
      opacity: isCurrentLine ? 1 : 0.6,
      transform: isCurrentLine ? 'scale(1.05)' : 'scale(1)',
      width: '100%'
    };
  };

  const gridItemStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '8px'
  };

  const toggleButtonStyle = (active: boolean): React.CSSProperties => ({
    padding: '8px 12px',
    backgroundColor: active ? '#0E639C' : '#3D3D3D',
    border: `1px solid ${active ? '#0E90FF' : '#4D4D4D'}`,
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '13px',
    transition: 'all 0.2s ease'
  });

  const animationGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'repeat(2, 1fr)',
    gap: '8px'
  };

  const animationButtonStyle = (isSelected: boolean): React.CSSProperties => ({
    padding: '12px 8px',
    backgroundColor: isSelected ? '#0E639C' : '#3D3D3D',
    border: `1px solid ${isSelected ? '#0E90FF' : '#4D4D4D'}`,
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '12px',
    transition: 'all 0.2s ease',
    textAlign: 'center'
  });

  const presetGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'repeat(5, 1fr)',
    gap: '8px',
    gridColumn: '1 / -1'
  };

  const presetButtonStyle: React.CSSProperties = {
    padding: '12px 8px',
    backgroundColor: '#3D3D3D',
    border: '1px solid #4D4D4D',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '11px',
    textAlign: 'center',
    transition: 'all 0.2s ease'
  };

  const headerStyle: React.CSSProperties = {
    padding: '16px 24px',
    borderBottom: '1px solid #3D3D3D',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center'
  };

  const footerStyle: React.CSSProperties = {
    padding: '16px 24px',
    borderTop: '1px solid #3D3D3D',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '12px'
  };

  const importButtonStyle: React.CSSProperties = {
    padding: '8px 12px',
    backgroundColor: '#0E639C',
    border: '1px solid #0E90FF',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '13px',
    transition: 'all 0.2s ease',
    marginBottom: '12px'
  };

  const importedItemStyle: React.CSSProperties = {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '8px',
    backgroundColor: '#3D3D3D',
    borderRadius: '4px',
    marginBottom: '6px',
    fontSize: '13px'
  };

  const deleteButtonStyle: React.CSSProperties = {
    padding: '4px 8px',
    backgroundColor: '#C5192D',
    border: 'none',
    borderRadius: '3px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '12px',
    transition: 'background-color 0.2s ease'
  };

  const thumbnailStyle: React.CSSProperties = {
    width: '100px',
    height: '60px',
    borderRadius: '4px',
    marginTop: '8px',
    marginBottom: '8px',
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    border: '1px solid #4D4D4D'
  };

  const buttonStyle: React.CSSProperties = {
    padding: '10px 24px',
    backgroundColor: '#0E639C',
    border: 'none',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
    transition: 'background-color 0.2s ease'
  };

  const closeButtonStyle: React.CSSProperties = {
    padding: '10px 24px',
    backgroundColor: '#3D3D3D',
    border: '1px solid #4D4D4D',
    borderRadius: '4px',
    color: '#FFFFFF',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
    transition: 'background-color 0.2s ease'
  };

  return (
    <div style={containerStyle}>
      {/* Header */}
      <div style={headerStyle}>
        <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600' }}>样式编辑器</h2>
        <button
          onClick={onClose}
          style={{
            background: 'none',
            border: 'none',
            color: '#CCCCCC',
            fontSize: '20px',
            cursor: 'pointer',
            padding: '0'
          }}
        >
          ✕
        </button>
      </div>

      {/* Content */}
      <div style={contentStyle}>
        {/* Animation Preview */}
        <div style={{ ...sectionStyle, gridColumn: '1 / -1' }}>
          <div style={sectionTitleStyle}>动画预览区</div>
          <div style={previewStyle}>
            {SAMPLE_LYRICS.map((lyric, index) => (
              <div key={index} style={previewLineStyle(index)}>
                {lyric}
              </div>
            ))}
          </div>
        </div>

        {/* Font Settings */}
        <div style={sectionStyle}>
          <div style={sectionTitleStyle}>字体设置</div>

          <div style={labelStyle}>
            <span>字体家族</span>
          </div>
          <select
            value={localStyle.fontName || 'Microsoft YaHei'}
            onChange={(e) => handleStyleChange({ fontName: e.target.value })}
            style={inputStyle as any}
          >
            <option value="Microsoft YaHei">Microsoft YaHei</option>
            <option value="Arial">Arial</option>
            <option value="Helvetica">Helvetica</option>
            <option value="Times New Roman">Times New Roman</option>
            <option value="Courier New">Courier New</option>
            <option value="Verdana">Verdana</option>
          </select>

          <div style={labelStyle}>
            <span>字体大小</span>
            <span>{localStyle.fontSize || 48}px</span>
          </div>
          <input
            type="range"
            min="20"
            max="120"
            value={localStyle.fontSize || 48}
            onChange={(e) => handleStyleChange({ fontSize: parseInt(e.target.value) })}
            style={sliderStyle}
          />

          <div style={labelStyle}>字体粗细</div>
          <div style={gridItemStyle}>
            {['regular', 'medium', 'semibold', 'bold', 'heavy'].map((weight) => (
              <button
                key={weight}
                onClick={() => handleStyleChange({ fontWeight: weight })}
                style={{
                  ...toggleButtonStyle(localStyle.fontWeight === weight),
                  textTransform: 'capitalize'
                }}
              >
                {weight === 'regular' ? '常规' : weight === 'medium' ? '中等' : weight === 'semibold' ? '半粗' : weight === 'bold' ? '粗体' : '超粗'}
              </button>
            ))}
          </div>
        </div>

        {/* Color Settings */}
        <div style={sectionStyle}>
          <div style={sectionTitleStyle}>颜色设置</div>

          <div style={labelStyle}>当前行颜色</div>
          <div style={colorPickerContainerStyle}>
            <input
              type="color"
              value={localStyle.currentLineColor || '#FFFFFF'}
              onChange={(e) => handleStyleChange({ currentLineColor: e.target.value })}
              style={colorPickerStyle}
            />
            <span style={{ fontSize: '12px', color: '#AAAAAA' }}>
              {localStyle.currentLineColor || '#FFFFFF'}
            </span>
          </div>

          <div style={labelStyle}>
            <span>发光效果</span>
          </div>
          <button
            onClick={() => handleStyleChange({ currentLineGlow: !localStyle.currentLineGlow })}
            style={toggleButtonStyle(localStyle.currentLineGlow || false)}
          >
            {localStyle.currentLineGlow ? '启用' : '禁用'}
          </button>

          <div style={{ marginTop: '12px' }}>
            <div style={labelStyle}>其他行颜色</div>
            <div style={colorPickerContainerStyle}>
              <input
                type="color"
                value={localStyle.otherLineColor || '#CCCCCC'}
                onChange={(e) => handleStyleChange({ otherLineColor: e.target.value })}
                style={colorPickerStyle}
              />
              <span style={{ fontSize: '12px', color: '#AAAAAA' }}>
                {localStyle.otherLineColor || '#CCCCCC'}
              </span>
            </div>
          </div>

          <div style={labelStyle}>已唱过行颜色</div>
          <div style={colorPickerContainerStyle}>
            <input
              type="color"
              value={localStyle.pastLineColor || '#888888'}
              onChange={(e) => handleStyleChange({ pastLineColor: e.target.value })}
              style={colorPickerStyle}
            />
            <span style={{ fontSize: '12px', color: '#AAAAAA' }}>
              {localStyle.pastLineColor || '#888888'}
            </span>
          </div>

          <div style={labelStyle}>背景颜色</div>
          <div style={colorPickerContainerStyle}>
            <input
              type="color"
              value={localStyle.backgroundColor || '#000000'}
              onChange={(e) => handleStyleChange({ backgroundColor: e.target.value })}
              style={colorPickerStyle}
            />
            <span style={{ fontSize: '12px', color: '#AAAAAA' }}>
              {localStyle.backgroundColor || '#000000'}
            </span>
          </div>

          <div style={labelStyle}>
            <span>背景透明度</span>
            <span>{Math.round((localStyle.backgroundOpacity || 0.8) * 100)}%</span>
          </div>
          <input
            type="range"
            min="0"
            max="1"
            step="0.1"
            value={localStyle.backgroundOpacity || 0.8}
            onChange={(e) => handleStyleChange({ backgroundOpacity: parseFloat(e.target.value) })}
            style={sliderStyle}
          />

          {/* Background Image Section */}
          <div style={{ marginTop: '16px', paddingTop: '12px', borderTop: '1px solid #4D4D4D' }}>
            <div style={labelStyle}>背景图片</div>
            <button
              onClick={handleSelectBackgroundImage}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#1177BB')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#0E639C')}
              style={importButtonStyle}
            >
              选择背景图片
            </button>

            {localStyle.backgroundImage && (
              <div>
                <div
                  style={{
                    ...thumbnailStyle,
                    backgroundImage: `url(file://${localStyle.backgroundImage})`
                  }}
                />
                <button
                  onClick={handleRemoveBackgroundImage}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#E81123')}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#C5192D')}
                  style={deleteButtonStyle}
                >
                  移除
                </button>
                <div style={{ fontSize: '12px', color: '#AAAAAA', marginTop: '6px', wordBreak: 'break-all' }}>
                  {localStyle.backgroundImage.split(/[\\/]/).pop()}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Font Import Section */}
        <div style={sectionStyle}>
          <div style={sectionTitleStyle}>字体导入</div>

          <button
            onClick={handleImportFont}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#1177BB')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#0E639C')}
            style={importButtonStyle}
          >
            导入字体
          </button>

          <div style={labelStyle}>已导入字体</div>
          {importedFonts.length > 0 ? (
            importedFonts.map((font) => (
              <div key={font} style={importedItemStyle}>
                <span>{font}</span>
                <button
                  onClick={() => handleRemoveFont(font)}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#E81123')}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#C5192D')}
                  style={deleteButtonStyle}
                >
                  删除
                </button>
              </div>
            ))
          ) : (
            <div style={{ fontSize: '13px', color: '#888888', padding: '8px', fontStyle: 'italic' }}>
              未导入任何字体
            </div>
          )}
        </div>

        {/* Animation Settings */}
        <div style={sectionStyle}>
          <div style={sectionTitleStyle}>动画设置</div>

          <div style={labelStyle}>动画风格</div>
          <div style={animationGridStyle}>
            {ANIMATION_OPTIONS.map((option) => (
              <button
                key={option.key}
                onClick={() => handleStyleChange({ animationStyle: option.key })}
                style={animationButtonStyle(localStyle.animationStyle === option.key)}
              >
                {option.label}
              </button>
            ))}
          </div>

          <div style={{ marginTop: '12px', ...labelStyle }}>
            <span>动画速度</span>
            <span>{(localStyle.animationSpeed || 0.5).toFixed(2)}</span>
          </div>
          <input
            type="range"
            min="0.1"
            max="1.0"
            step="0.1"
            value={localStyle.animationSpeed || 0.5}
            onChange={(e) => handleStyleChange({ animationSpeed: parseFloat(e.target.value) })}
            style={sliderStyle}
          />
        </div>

        {/* Layout Settings */}
        <div style={sectionStyle}>
          <div style={sectionTitleStyle}>布局设置</div>

          <div style={labelStyle}>文本对齐</div>
          <div style={gridItemStyle}>
            {['leading', 'center', 'trailing'].map((align) => (
              <button
                key={align}
                onClick={() => handleStyleChange({ alignment: align })}
                style={{
                  ...toggleButtonStyle(localStyle.alignment === align)
                }}
              >
                {align === 'leading' ? '左对齐' : align === 'center' ? '居中' : '右对齐'}
              </button>
            ))}
          </div>

          <div style={{ marginTop: '12px', ...labelStyle }}>
            <span>行间距</span>
            <span>{localStyle.lineSpacing || 20}px</span>
          </div>
          <input
            type="range"
            min="5"
            max="60"
            value={localStyle.lineSpacing || 20}
            onChange={(e) => handleStyleChange({ lineSpacing: parseInt(e.target.value) })}
            style={sliderStyle}
          />

          <div style={labelStyle}>
            <span>显示翻译</span>
          </div>
          <button
            onClick={() => handleStyleChange({ showTranslation: !localStyle.showTranslation })}
            style={toggleButtonStyle(localStyle.showTranslation || false)}
          >
            {localStyle.showTranslation ? '启用' : '禁用'}
          </button>

          <div style={{ marginTop: '12px', ...labelStyle }}>
            <span>可见行数</span>
            <span>{localStyle.visibleLineCount || 4}</span>
          </div>
          <input
            type="range"
            min="3"
            max="10"
            value={localStyle.visibleLineCount || 4}
            onChange={(e) => handleStyleChange({ visibleLineCount: parseInt(e.target.value) })}
            style={sliderStyle}
          />

          <div style={{ marginTop: '12px', ...labelStyle }}>
            <span>内边距</span>
            <span>{localStyle.padding || 20}px</span>
          </div>
          <input
            type="range"
            min="10"
            max="100"
            value={localStyle.padding || 20}
            onChange={(e) => handleStyleChange({ padding: parseInt(e.target.value) })}
            style={sliderStyle}
          />
        </div>

        {/* Theme Presets */}
        <div style={{ ...sectionStyle, gridColumn: '1 / -1' }}>
          <div style={sectionTitleStyle}>主题预设</div>
          <div style={presetGridStyle}>
            {THEME_PRESETS.map((preset) => (
              <button
                key={preset.name}
                onClick={() => handleApplyPreset(preset)}
                style={{
                  ...presetButtonStyle,
                  backgroundColor: colorToHex(preset.style.currentLineColor) || '#3D3D3D',
                  opacity: 0.7
                }}
              >
                {preset.name}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Footer */}
      <div style={footerStyle}>
        <button
          onClick={onClose}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#505050')}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#3D3D3D')}
          style={closeButtonStyle}
        >
          关闭
        </button>
        <button
          onClick={onClose}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#1177BB')}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#0E639C')}
          style={buttonStyle}
        >
          完成
        </button>
      </div>
    </div>
  );
};

export default StyleEditorView;
