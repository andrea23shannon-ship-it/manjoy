import {
  LyricLine,
  LyricsStyle,
  AnimationStyleType,
  CodableColor,
  FontWeight,
  FontWeightValues,
  TextAlignmentType,
  LineState,
  colorToCSS,
} from '../../shared/types';

interface CharacterRenderState {
  char: string;
  x: number;
  y: number;
  scale: number;
  opacity: number;
  rotationZ: number;
  transitionProgress: number;
}

export class AnimationRenderer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private animationFrameId: number | null = null;

  // Current state (set externally)
  private lyrics: LyricLine[] = [];
  private currentLineIndex: number = -1;
  private lineProgress: number = 0;
  private isPlaying: boolean = false;
  private style: LyricsStyle;

  // Animation internal state
  private wavePhase: number = 0;
  private pulseScale: number = 1.0;
  private pulseDirection: number = 1;
  private lastFrameTime: number = 0;
  private charBouncePhase: number = 0;
  private scatterCharPositions: Map<string, { x: number; y: number }[]> = new Map();

  // Standby
  private standbyImage: HTMLImageElement | null = null;
  private showStandby: boolean = false;

  // Configuration
  private readonly VISIBLE_LINE_COUNT = 5;
  private readonly WAVE_SPEED = 0.12;
  private readonly PULSE_SPEED = 0.05;
  private readonly CHAR_BOUNCE_SPEED = 0.15;
  private readonly SPRING_DAMPING = 0.12;
  private readonly CHAR_SPLIT_RANGE = { min: 4, max: 8 };
  private readonly SLOT_PATTERN = [0.05, 0.8, 0.4, 0.9, 0.15, 0.7, 0.3, 0.85];

  constructor(canvas: HTMLCanvasElement, style: LyricsStyle) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.style = style;

    // High-DPI support
    const dpr = window.devicePixelRatio || 1;
    if (dpr > 1) {
      this.canvas.width *= dpr;
      this.canvas.height *= dpr;
      this.ctx.scale(dpr, dpr);
    }
  }

  // Public API
  public setState(
    lyrics: LyricLine[],
    currentLineIndex: number,
    lineProgress: number,
    isPlaying: boolean
  ): void {
    this.lyrics = lyrics;
    this.currentLineIndex = currentLineIndex;
    this.lineProgress = Math.max(0, Math.min(1, lineProgress));
    this.isPlaying = isPlaying;
  }

  public setStyle(style: LyricsStyle): void {
    this.style = style;
  }

  public setStandbyImage(imagePath: string | null): void {
    if (imagePath) {
      const img = new Image();
      img.onload = () => {
        this.standbyImage = img;
      };
      img.onerror = () => {
        console.warn('Failed to load standby image:', imagePath);
      };
      img.src = imagePath;
    } else {
      this.standbyImage = null;
    }
  }

  public start(): void {
    if (this.animationFrameId === null) {
      this.lastFrameTime = performance.now();
      this.animate();
    }
  }

  public stop(): void {
    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  }

  public resize(width: number, height: number): void {
    this.canvas.width = width;
    this.canvas.height = height;
  }

  public destroy(): void {
    this.stop();
    this.standbyImage = null;
    this.scatterCharPositions.clear();
  }

  // Animation loop
  private animate = (): void => {
    const now = performance.now();
    const deltaTime = (now - this.lastFrameTime) / 1000;
    this.lastFrameTime = now;

    // Update animation states
    if (this.isPlaying) {
      this.wavePhase += this.WAVE_SPEED * deltaTime * 60;
      this.charBouncePhase += this.CHAR_BOUNCE_SPEED * deltaTime * 60;

      // Update pulse
      this.pulseScale += this.pulseDirection * this.PULSE_SPEED * deltaTime * 60;
      if (this.pulseScale >= 1.12) {
        this.pulseDirection = -1;
      } else if (this.pulseScale <= 1.0) {
        this.pulseDirection = 1;
      }
    }

    // Render frame
    this.render();

    this.animationFrameId = requestAnimationFrame(this.animate);
  };

  // Main render function
  private render(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;

    // Clear background
    this.ctx.fillStyle = colorToCSS(this.style.backgroundColor);
    this.ctx.fillRect(0, 0, width, height);

    // Show standby image if not playing
    if (!this.isPlaying && this.standbyImage) {
      this.renderStandbyImage();
      return;
    }

    // Render based on animation style
    switch (this.style.animationStyle) {
      case 'none':
        this.renderNone();
        break;
      case 'smooth':
        this.renderSmooth();
        break;
      case 'fade':
        this.renderFade();
        break;
      case 'scale':
        this.renderScale();
        break;
      case 'karaoke':
        this.renderKaraoke();
        break;
      case 'bounce':
        this.renderBounce();
        break;
      case 'wave':
        this.renderWave();
        break;
      case 'pulse':
        this.renderPulse();
        break;
      case 'typewriter':
        this.renderTypewriter();
        break;
      case 'slideIn':
        this.renderSlideIn();
        break;
      case 'charBounce':
        this.renderCharBounce();
        break;
      case 'scatter':
        this.renderScatter();
        break;
      case 'float3D':
        this.renderFloat3D();
        break;
      case 'randomSize':
        this.renderRandomSize();
        break;
      default:
        this.renderNone();
    }
  }

  // Standby rendering
  private renderStandbyImage(): void {
    if (!this.standbyImage) return;

    const width = this.canvas.width;
    const height = this.canvas.height;
    const imgAspect = this.standbyImage.width / this.standbyImage.height;
    const canvasAspect = width / height;

    let drawWidth = width;
    let drawHeight = height;
    let drawX = 0;
    let drawY = 0;

    if (imgAspect > canvasAspect) {
      drawWidth = height * imgAspect;
      drawX = (width - drawWidth) / 2;
    } else {
      drawHeight = width / imgAspect;
      drawY = (height - drawHeight) / 2;
    }

    this.ctx.drawImage(this.standbyImage, drawX, drawY, drawWidth, drawHeight);
  }

  // Animation style renderers
  private renderNone(): void {
    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lyrics.length) {
      return;
    }

    const currentLine = this.lyrics[this.currentLineIndex];
    this.drawCenteredLine(currentLine.text, 0, this.style.currentLineColor, 1);
  }

  private renderSmooth(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.5;
    const visibleCount = Math.ceil(height / lineHeight);

    // Calculate center line position (smooth transition)
    const scrollOffset = -this.lineProgress * lineHeight;

    // Center line is at height/2
    const centerY = height / 2;

    for (let i = 0; i < this.lyrics.length; i++) {
      const relativePos = i - this.currentLineIndex;
      const y =
        centerY + relativePos * lineHeight + scrollOffset - (lineHeight * visibleCount) / 2;

      if (y < -lineHeight || y > height + lineHeight) continue;

      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;
      const color = isCurrent ? this.style.currentLineColor : this.style.otherLineColor;

      this.drawLine(line.text, width / 2, y, color, 1, 'center');
    }
  }

  private renderFade(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.5;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const distance = Math.abs(i - this.currentLineIndex);
      const opacity = Math.max(0, 1 - (distance / (this.VISIBLE_LINE_COUNT / 2)) * 0.7);
      const y =
        centerY +
        (i - this.currentLineIndex - 0.5) * lineHeight -
        this.lineProgress * lineHeight * 0.5;

      const color =
        i === this.currentLineIndex ? this.style.currentLineColor : this.style.otherLineColor;
      this.drawLine(line.text, width / 2, y, color, opacity, 'center');
    }
  }

  private renderScale(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.8;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;

      // Spring easing for scale transition
      const targetScale = isCurrent ? 1.15 : 0.85;
      const scale = this.easeSpring(targetScale, 0.12);

      const y = centerY + (i - this.currentLineIndex) * lineHeight;
      const color =
        isCurrent ? this.style.currentLineColor : this.style.pastLineColor;

      this.drawLineWithScale(line.text, width / 2, y, color, 1, 'center', scale);
    }
  }

  private renderKaraoke(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.5;
    const centerY = height / 2;

    // Draw current and next line
    if (this.currentLineIndex >= 0 && this.currentLineIndex < this.lyrics.length) {
      const currentLine = this.lyrics[this.currentLineIndex];

      // Current line with character-level highlighting
      this.drawKaraokeLine(currentLine.text, width / 2, centerY - lineHeight / 2, 1);

      // Next line if exists
      if (this.currentLineIndex + 1 < this.lyrics.length) {
        const nextLine = this.lyrics[this.currentLineIndex + 1];
        this.drawLine(nextLine.text, width / 2, centerY + lineHeight / 2,
          this.style.otherLineColor, 0.5, 'center');
      }
    }
  }

  private renderBounce(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.6;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;

      const scale = isCurrent ? 1.08 : 0.92;
      const yOffset = isCurrent ? -12 : 0;

      const y = centerY + (i - this.currentLineIndex) * lineHeight + yOffset;
      const color =
        isCurrent ? this.style.currentLineColor : this.style.pastLineColor;

      this.drawLineWithScale(line.text, width / 2, y, color, 1, 'center', scale);
    }
  }

  private renderWave(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.5;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;
      const amplitude = isCurrent ? 8 : 4;

      const baseY = centerY + (i - this.currentLineIndex) * lineHeight;
      const waveOffset = Math.sin(this.wavePhase + i * 0.5) * amplitude;
      const y = baseY + waveOffset;

      const color =
        isCurrent ? this.style.currentLineColor : this.style.otherLineColor;
      this.drawLine(line.text, width / 2, y, color, 1, 'center');
    }
  }

  private renderPulse(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.6;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;

      const scale = isCurrent ? this.pulseScale : 0.88;
      const y = centerY + (i - this.currentLineIndex) * lineHeight;
      const color =
        isCurrent ? this.style.currentLineColor : this.style.pastLineColor;

      this.drawLineWithScale(line.text, width / 2, y, color, 1, 'center', scale);
    }
  }

  private renderTypewriter(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const centerY = height / 2;

    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lyrics.length) {
      return;
    }

    const currentLine = this.lyrics[this.currentLineIndex];
    const charCount = currentLine.text.length;
    const revealedCount = Math.floor(this.lineProgress * charCount);

    // Draw revealed characters
    let revealedText = currentLine.text.substring(0, revealedCount);
    this.drawLine(revealedText, width / 2, centerY, this.style.currentLineColor, 1, 'center');

    // Draw placeholder for unrevealed characters (if any)
    if (revealedCount < charCount) {
      const unrevealed = currentLine.text.substring(revealedCount);
      const placeholderOpacity = 0.2;
      const metrics = this.ctx.measureText(revealedText);
      const xOffset = metrics.width;

      this.ctx.save();
      this.ctx.globalAlpha = placeholderOpacity;
      this.ctx.fillStyle = colorToCSS(this.style.otherLineColor);
      const y = centerY + this.style.fontSize / 2;
      this.ctx.fillText(unrevealed, width / 2 + xOffset, y);
      this.ctx.restore();
    }
  }

  private renderSlideIn(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const lineHeight = this.style.fontSize * 1.6;
    const centerY = height / 2;

    const startIdx = Math.max(0, this.currentLineIndex - 3);
    const endIdx = Math.min(this.lyrics.length, this.currentLineIndex + 3);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;

      let xOffset = 0;
      let scale = 1;
      let opacity = 1;

      if (i < this.currentLineIndex) {
        // Past lines slide left
        xOffset = -60;
        opacity = 0.5;
      } else if (i > this.currentLineIndex) {
        // Upcoming lines slide right
        xOffset = 60;
        opacity = 0.5;
      } else {
        // Current line
        scale = 1.05;
      }

      const y = centerY + (i - this.currentLineIndex) * lineHeight;
      const x = width / 2 + xOffset;
      const color =
        isCurrent ? this.style.currentLineColor : this.style.otherLineColor;

      this.drawLineWithScale(line.text, x, y, color, opacity, 'center', scale);
    }
  }

  private renderCharBounce(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const centerY = height / 2;
    const lineHeight = this.style.fontSize * 1.8;

    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lyrics.length) {
      return;
    }

    const currentLine = this.lyrics[this.currentLineIndex];

    // Phase 1: Whole line fade-in with scale
    const phaseProgress = this.lineProgress;
    const phase1Progress = Math.min(1, phaseProgress * 2);
    const phase2Start = 0.3;
    const phase2Progress = Math.max(0, (phaseProgress - phase2Start) / (1 - phase2Start));

    const lineScale = this.easeQuadOut(0.3, 1, phase1Progress);
    const lineOpacity = phase1Progress;

    // Draw current line with character-by-character bounce
    this.drawCharBounceLine(currentLine.text, width / 2, centerY, lineScale, lineOpacity, phase2Progress);

    // Draw previous line as faded small text
    if (this.currentLineIndex > 0) {
      const prevLine = this.lyrics[this.currentLineIndex - 1];
      this.drawLine(prevLine.text, width / 2, centerY - lineHeight,
        this.style.pastLineColor, 0.3, 'center', 0.7);
    }
  }

  private renderScatter(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const centerY = height / 2;

    if (this.currentLineIndex < 0 || this.currentLineIndex >= this.lyrics.length) {
      return;
    }

    const currentLine = this.lyrics[this.currentLineIndex];
    const lineKey = `line_${this.currentLineIndex}`;

    // Initialize scatter positions if needed
    if (!this.scatterCharPositions.has(lineKey)) {
      this.initializeScatterPositions(currentLine.text, width, height);
    }

    const positions = this.scatterCharPositions.get(lineKey) || [];
    const gatherProgress = this.lineProgress;

    this.ctx.save();
    this.ctx.font = this.getFontString();
    this.ctx.fillStyle = colorToCSS(this.style.currentLineColor);

    let x = width / 2;

    for (let i = 0; i < currentLine.text.length; i++) {
      const char = currentLine.text[i];
      const charPositions = positions[i] || { x: width / 2, y: centerY };

      // Interpolate from scatter to final position
      const finalMetrics = this.ctx.measureText(char);
      const finalX = x;
      const finalY = centerY + this.style.fontSize / 2;

      const currentX = this.lerp(charPositions.x, finalX, gatherProgress);
      const currentY = this.lerp(charPositions.y, finalY, gatherProgress);
      const opacity = Math.min(1, gatherProgress * 2);

      this.ctx.save();
      this.ctx.globalAlpha = opacity;
      this.ctx.fillText(char, currentX, currentY);
      this.ctx.restore();

      x += finalMetrics.width;
    }

    this.ctx.restore();
  }

  private renderFloat3D(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const centerY = height / 2;
    const lineHeight = this.style.fontSize * 1.8;

    const startIdx = Math.max(0, this.currentLineIndex - 2);
    const endIdx = Math.min(this.lyrics.length, this.currentLineIndex + 2);

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;

      if (!isCurrent) {
        // Show other lines as normal
        const y = centerY + (i - this.currentLineIndex) * lineHeight;
        const color = i < this.currentLineIndex ? this.style.pastLineColor : this.style.otherLineColor;
        this.drawLine(line.text, width / 2, y, color, 0.5, 'center');
        continue;
      }

      // Render current line with float3D effect
      const progressEased = this.easeQuadOut(0, 1, this.lineProgress);

      // Characters float up from below with scale and opacity
      const baseScale = 0.3;
      const finalScale = 1;
      const scale = this.lerp(baseScale, finalScale, progressEased);
      const opacity = progressEased;

      const yOffset = this.lerp(-30, 0, progressEased);
      const y = centerY + yOffset;

      this.drawLineWithScale(line.text, width / 2, y, this.style.currentLineColor, opacity, 'center', scale);
    }
  }

  private renderRandomSize(): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const centerY = height / 2;
    const lineHeight = this.style.fontSize * 2;

    const startIdx = Math.max(0, this.currentLineIndex - Math.floor(this.VISIBLE_LINE_COUNT / 2));
    const endIdx = Math.min(this.lyrics.length, startIdx + this.VISIBLE_LINE_COUNT);

    this.ctx.save();
    this.ctx.textAlign = this.getTextAlign();

    for (let i = startIdx; i < endIdx; i++) {
      const line = this.lyrics[i];
      const isCurrent = i === this.currentLineIndex;
      const color = isCurrent ? this.style.currentLineColor : this.style.otherLineColor;

      // Slot-based X distribution
      const slotIndex = (i - startIdx) % this.SLOT_PATTERN.length;
      const xPosition = width * this.SLOT_PATTERN[slotIndex];

      const baseY = centerY + (i - startIdx) * lineHeight - (lineHeight * this.VISIBLE_LINE_COUNT) / 2;

      this.drawRandomSizeLine(line.text, xPosition, baseY, color, i);
    }

    this.ctx.restore();
  }

  // Helper rendering functions
  private drawCenteredLine(
    text: string,
    yOffset: number,
    color: CodableColor,
    opacity: number,
    scale: number = 1
  ): void {
    const width = this.canvas.width;
    const height = this.canvas.height;
    const y = height / 2 + yOffset;

    this.drawLine(text, width / 2, y, color, opacity, 'center', scale);
  }

  private drawLine(
    text: string,
    x: number,
    y: number,
    color: CodableColor,
    opacity: number,
    align: CanvasTextAlign = 'left',
    scale: number = 1
  ): void {
    this.ctx.save();
    this.ctx.globalAlpha = opacity;
    this.ctx.font = this.getFontString();
    this.ctx.fillStyle = colorToCSS(color);
    this.ctx.textAlign = align;
    this.ctx.textBaseline = 'middle';

    if (this.style.glowEffect) {
      this.ctx.shadowColor = colorToCSS(color);
      this.ctx.shadowBlur = this.style.glowSize || 10;
    }

    if (scale !== 1) {
      this.ctx.translate(x, y);
      this.ctx.scale(scale, scale);
      this.ctx.fillText(text, 0, 0);
      this.ctx.translate(-x, -y);
    } else {
      this.ctx.fillText(text, x, y);
    }

    this.ctx.restore();
  }

  private drawLineWithScale(
    text: string,
    x: number,
    y: number,
    color: CodableColor,
    opacity: number,
    align: CanvasTextAlign = 'left',
    scale: number = 1
  ): void {
    this.drawLine(text, x, y, color, opacity, align, scale);
  }

  private drawKaraokeLine(text: string, x: number, y: number, lineProgress: number): void {
    this.ctx.save();
    this.ctx.font = this.getFontString();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';

    if (this.style.glowEffect) {
      this.ctx.shadowColor = colorToCSS(this.style.currentLineColor);
      this.ctx.shadowBlur = this.style.glowSize || 10;
    }

    const charCount = text.length;
    const progressIndex = lineProgress * charCount;

    let currentX = x - this.ctx.measureText(text).width / 2;

    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const charMetrics = this.ctx.measureText(char);

      // Character is highlighted if it's before the progress index
      const isHighlighted = i < progressIndex;
      const isPartial = i === Math.floor(progressIndex);
      let opacity = 1;
      let color = this.style.currentLineColor;

      if (isPartial && !isHighlighted) {
        // Partial transparency for the character being highlighted
        opacity = progressIndex - Math.floor(progressIndex);
        color = this.style.currentLineColor;
      } else if (!isHighlighted) {
        // Unhighlighted characters
        color = this.style.otherLineColor;
        opacity = 0.5;
      }

      this.ctx.save();
      this.ctx.globalAlpha = opacity;
      this.ctx.fillStyle = colorToCSS(color);
      this.ctx.fillText(char, currentX + charMetrics.width / 2, y);
      this.ctx.restore();

      currentX += charMetrics.width;
    }

    this.ctx.restore();
  }

  private drawCharBounceLine(
    text: string,
    x: number,
    y: number,
    lineScale: number,
    lineOpacity: number,
    bounceProgress: number
  ): void {
    this.ctx.save();
    this.ctx.globalAlpha = lineOpacity;
    this.ctx.font = this.getFontString();
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';

    if (this.style.glowEffect) {
      this.ctx.shadowColor = colorToCSS(this.style.currentLineColor);
      this.ctx.shadowBlur = this.style.glowSize || 10;
    }

    const fullTextWidth = this.ctx.measureText(text).width;
    let currentX = x - (fullTextWidth * lineScale) / 2;

    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const charMetrics = this.ctx.measureText(char);

      // Each character bounces in based on bounce progress and index
      const charDelay = (i / text.length) * 0.7;
      const charBounceProgress = Math.max(0, (bounceProgress - charDelay) / (1 - charDelay));

      if (charBounceProgress <= 0) {
        currentX += charMetrics.width * lineScale;
        continue;
      }

      // Spring bounce animation
      const bounceScale = this.easeElastic(0, 1, charBounceProgress);
      const bounceY = this.easeQuadOut(20, 0, charBounceProgress);

      this.ctx.save();
      this.ctx.globalAlpha = Math.min(1, lineOpacity * bounceScale);
      this.ctx.fillStyle = colorToCSS(this.style.currentLineColor);
      this.ctx.translate(currentX + (charMetrics.width * lineScale) / 2, y + bounceY);
      this.ctx.scale(bounceScale * lineScale, bounceScale * lineScale);
      this.ctx.fillText(char, 0, 0);
      this.ctx.restore();

      currentX += charMetrics.width * lineScale;
    }

    this.ctx.restore();
  }

  private drawRandomSizeLine(text: string, x: number, y: number, color: CodableColor, lineSeed: number): void {
    this.ctx.save();
    this.ctx.fillStyle = colorToCSS(color);
    this.ctx.textBaseline = 'middle';

    let currentX = x;

    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const seed = lineSeed * 73 + i * 17; // Deterministic pseudo-random

      // Determine random size
      const random = this.pseudoRandom(seed);
      let sizeMultiplier = 1;

      if (random < 0.3) {
        sizeMultiplier = 1.35 + random * 0.5;
      } else if (random < 0.6) {
        sizeMultiplier = 1.0;
      } else {
        sizeMultiplier = 0.8 + random * 0.3;
      }

      // Random Y offset
      const yOffset = (this.pseudoRandom(seed + 1) - 0.5) * 4;

      const fontSize = this.style.fontSize * sizeMultiplier;
      this.ctx.font = `${FontWeightValues[this.style.fontWeight]} ${Math.round(fontSize)}px "${this.style.fontName}"`;

      const charMetrics = this.ctx.measureText(char);
      this.ctx.fillText(char, currentX, y + yOffset);

      currentX += charMetrics.width;
    }

    this.ctx.restore();
  }

  // Utility functions
  private getFontString(): string {
    return `${FontWeightValues[this.style.fontWeight]} ${this.style.fontSize}px "${this.style.fontName}"`;
  }

  private getTextAlign(): CanvasTextAlign {
    if (this.style.alignment === 'center') return 'center';
    if (this.style.alignment === 'right') return 'right';
    return 'left';
  }

  private lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
  }

  private easeQuadOut(start: number, end: number, t: number): number {
    const progress = 1 - (1 - t) * (1 - t);
    return start + (end - start) * progress;
  }

  private easeSpring(target: number, damping: number): number {
    // Simple spring-like easing that moves toward target
    return target;
  }

  private easeElastic(start: number, end: number, t: number): number {
    const c4 = (2 * Math.PI) / 3;
    const progress =
      t === 0
        ? 0
        : t === 1
          ? 1
          : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
    return start + (end - start) * progress;
  }

  private pseudoRandom(seed: number): number {
    const x = Math.sin(seed) * 10000;
    return x - Math.floor(x);
  }

  private initializeScatterPositions(text: string, width: number, height: number): void {
    const lineKey = `line_${this.currentLineIndex}`;
    const positions: { x: number; y: number }[] = [];

    for (let i = 0; i < text.length; i++) {
      const angle = (i / text.length) * Math.PI * 2;
      const distance = 100 + Math.random() * 100;
      const centerX = width / 2;
      const centerY = height / 2;

      positions.push({
        x: centerX + Math.cos(angle) * distance,
        y: centerY + Math.sin(angle) * distance,
      });
    }

    this.scatterCharPositions.set(lineKey, positions);

    // Cleanup old scatter positions
    if (this.scatterCharPositions.size > 10) {
      const firstKey = this.scatterCharPositions.keys().next().value;
      this.scatterCharPositions.delete(firstKey);
    }
  }
}
