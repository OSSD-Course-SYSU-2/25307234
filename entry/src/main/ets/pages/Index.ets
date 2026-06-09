// pages/FishGame.ets
// 大鱼吃小鱼游戏 - HarmonyOS ArkTS Canvas 实现

/** 鱼的类型 */
enum FishType {
  PLAYER = 'player',
  SMALL = 'small',
  BIG = 'big'
}

/** 游戏状态 */
enum GameState {
  READY = 'ready',
  PLAYING = 'playing',
  OVER = 'over',
  WIN = 'win'
}

/** 鱼的数据结构 */
interface FishItem {
  x: number;
  y: number;
  size: number;
  speedX: number;
  speedY: number;
  color: string;
  type: FishType;
  angle: number;
  targetAngle: number;
  tailColor: string;
}

/** 粒子数据结构 */
interface ParticleItem {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  color: string;
  size: number;
}

/** 气泡装饰 */
interface BubbleItem {
  x: number;
  y: number;
  radius: number;
  speed: number;
  opacity: number;
}

// ==================== 游戏配置 ====================
interface GeneratedObjectLiteralInterface_1 {
  CANVAS_WIDTH: number;
  CANVAS_HEIGHT: number;
  PLAYER_INIT_SIZE: number;
  PLAYER_SPEED: number;
  PLAYER_COLOR: string;
  PLAYER_TAIL_COLOR: string;
  SMALL_FISH_MIN_SIZE: number;
  SMALL_FISH_MAX_SIZE: number;
  SMALL_FISH_COUNT: number;
  SMALL_FISH_SPEED: number;
  BIG_FISH_MIN_SIZE: number;
  BIG_FISH_MAX_SIZE: number;
  BIG_FISH_COUNT: number;
  BIG_FISH_SPEED: number;
  SIZE_GROW: number;
  SCORE_PER_FISH: number;
  BUBBLE_COUNT: number;
  PARTICLE_COUNT: number;
  PARTICLE_LIFE: number;
  TOUCH_SENSITIVITY: number;
  WATER_COLOR_TOP: string;
  WATER_COLOR_BOTTOM: string;
}

const CONFIG: GeneratedObjectLiteralInterface_1 = {
  CANVAS_WIDTH: 360,
  CANVAS_HEIGHT: 640,
  PLAYER_INIT_SIZE: 25,
  PLAYER_SPEED: 4,
  PLAYER_COLOR: '#FF8C42',
  PLAYER_TAIL_COLOR: '#E6732C',
  SMALL_FISH_MIN_SIZE: 10,
  SMALL_FISH_MAX_SIZE: 20,
  SMALL_FISH_COUNT: 12,
  SMALL_FISH_SPEED: 1.5,
  BIG_FISH_MIN_SIZE: 35,
  BIG_FISH_MAX_SIZE: 85,
  BIG_FISH_COUNT: 2,
  BIG_FISH_SPEED: 1.8,
  SIZE_GROW: 2,
  SCORE_PER_FISH: 10,
  BUBBLE_COUNT: 15,
  PARTICLE_COUNT: 8,
  PARTICLE_LIFE: 25,
  TOUCH_SENSITIVITY: 0.15,
  WATER_COLOR_TOP: '#1a3a5c',
  WATER_COLOR_BOTTOM: '#0a1a2e'
};

// ==================== 小鱼颜色池 ====================
const SMALL_FISH_COLORS: string[] = [
  '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
  '#DDA0DD', '#98FB98', '#87CEEB', '#F0E68C',
  '#7FDBFF', '#01FF70', '#B10DC9', '#39CCCC'
];

const SMALL_FISH_TAIL_COLORS: string[] = [
  '#36B5AC', '#2D9FB9', '#7EB69C', '#E7D28F',
  '#C588C5', '#80E380', '#6FB6D3', '#D8CE74'
];

// ==================== 大鱼颜色池 ====================
const BIG_FISH_COLORS: string[] = [
  '#FF4444', '#E74C3C', '#C0392B', '#FF6B6B',
  '#FF4757', '#EE5A24'
];

// ==================== 颜色转换工具 ====================
function hexToRgba(hex: string, alpha: number): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// ==================== 随机数工具 ====================
function rand(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

function randInt(min: number, max: number): number {
  return Math.floor(rand(min, max + 1));
}

function lerpAngle(current: number, target: number, t: number): number {
  let diff = target - current;
  while (diff > Math.PI) {
    diff -= Math.PI * 2;
  }
  while (diff < -Math.PI) {
    diff += Math.PI * 2;
  }
  return current + diff * t;
}

// ==================== 主游戏组件 ====================
@Entry
@Component
struct FishGame {
  // Canvas 上下文
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  // 游戏状态
  @State gameState: GameState = GameState.READY;
  @State score: number = 0;
  @State playerSize: number = CONFIG.PLAYER_INIT_SIZE;
  // Canvas 实际尺寸
  private canvasWidth: number = CONFIG.CANVAS_WIDTH;
  private canvasHeight: number = CONFIG.CANVAS_HEIGHT;
  // 游戏循环定时器
  private gameTimer: number = -1;
  private frameCount: number = 0;
  // 游戏对象
  private player: FishItem = this.createPlayerFish();
  private smallFishes: FishItem[] = [];
  private bigFishes: FishItem[] = [];
  private particles: ParticleItem[] = [];
  private bubbles: BubbleItem[] = [];
  // 触摸控制
  private touchActive: boolean = false;
  private touchTargetX: number = 0;
  private touchTargetY: number = 0;
  // 键盘控制
  private keysDown: Set<string> = new Set();
  // 方向键按下状态（虚拟按钮）
  @State btnUpPressed: boolean = false;
  @State btnDownPressed: boolean = false;
  @State btnLeftPressed: boolean = false;
  @State btnRightPressed: boolean = false;

  // ==================== 生命周期 ====================
  aboutToAppear(): void {
    this.initGame();
  }

  aboutToDisappear(): void {
    this.stopGameLoop();
  }

  // ==================== 初始化 ====================
  private initGame(): void {
    this.score = 0;
    this.playerSize = CONFIG.PLAYER_INIT_SIZE;
    this.player = this.createPlayerFish();
    this.smallFishes = [];
    this.bigFishes = [];
    this.particles = [];
    this.bubbles = [];
    this.frameCount = 0;

    // 生成小鱼
    for (let i = 0; i < CONFIG.SMALL_FISH_COUNT; i++) {
      this.smallFishes.push(this.createSmallFish());
    }

    // 生成大鱼
    for (let i = 0; i < CONFIG.BIG_FISH_COUNT; i++) {
      this.bigFishes.push(this.createBigFish());
    }

    // 生成气泡
    for (let i = 0; i < CONFIG.BUBBLE_COUNT; i++) {
      this.bubbles.push(this.createBubble());
    }
  }

  private createPlayerFish(): FishItem {
    return {
      x: CONFIG.CANVAS_WIDTH / 2,
      y: CONFIG.CANVAS_HEIGHT / 2,
      size: CONFIG.PLAYER_INIT_SIZE,
      speedX: 0,
      speedY: 0,
      color: CONFIG.PLAYER_COLOR,
      type: FishType.PLAYER,
      angle: 0,
      targetAngle: 0,
      tailColor: CONFIG.PLAYER_TAIL_COLOR
    };
  }

  private createSmallFish(): FishItem {
    const size = rand(CONFIG.SMALL_FISH_MIN_SIZE, CONFIG.SMALL_FISH_MAX_SIZE);
    const colorIndex = randInt(0, SMALL_FISH_COLORS.length - 1);
    const angle = rand(0, Math.PI * 2);
    const speed = CONFIG.SMALL_FISH_SPEED * rand(0.5, 1.5);

    return {
      x: rand(size + 10, CONFIG.CANVAS_WIDTH - size - 10),
      y: rand(size + 10, CONFIG.CANVAS_HEIGHT - size - 60),
      size: size,
      speedX: Math.cos(angle) * speed,
      speedY: Math.sin(angle) * speed,
      color: SMALL_FISH_COLORS[colorIndex],
      type: FishType.SMALL,
      angle: angle,
      targetAngle: angle,
      tailColor: SMALL_FISH_TAIL_COLORS[colorIndex % SMALL_FISH_TAIL_COLORS.length]
    };
  }

  private createBigFish(): FishItem {
    const size = rand(CONFIG.BIG_FISH_MIN_SIZE, CONFIG.BIG_FISH_MAX_SIZE);
    const colorIndex = randInt(0, BIG_FISH_COLORS.length - 1);
    const angle = rand(0, Math.PI * 2);
    const speed = CONFIG.BIG_FISH_SPEED * rand(0.6, 1.2);

    // 大鱼从边缘生成
    let x: number, y: number;
    const side = randInt(0, 3);
    switch (side) {
      case 0:
        x = -size;
        y = rand(0, CONFIG.CANVAS_HEIGHT);
        break;
      case 1:
        x = CONFIG.CANVAS_WIDTH + size;
        y = rand(0, CONFIG.CANVAS_HEIGHT);
        break;
      case 2:
        x = rand(0, CONFIG.CANVAS_WIDTH);
        y = -size;
        break;
      default:
        x = rand(0, CONFIG.CANVAS_WIDTH); y = CONFIG.CANVAS_HEIGHT + size; break;
    }

    return {
      x: x,
      y: y,
      size: size,
      speedX: Math.cos(angle) * speed,
      speedY: Math.sin(angle) * speed,
      color: BIG_FISH_COLORS[colorIndex],
      type: FishType.BIG,
      angle: angle,
      targetAngle: angle,
      tailColor: '#AA2222'
    };
  }

  private createBubble(): BubbleItem {
    return {
      x: rand(0, CONFIG.CANVAS_WIDTH),
      y: rand(0, CONFIG.CANVAS_HEIGHT),
      radius: rand(2, 8),
      speed: rand(0.3, 1.5),
      opacity: rand(0.15, 0.35)
    };
  }

  private createParticles(x: number, y: number, color: string): void {
    for (let i = 0; i < CONFIG.PARTICLE_COUNT; i++) {
      const angle = rand(0, Math.PI * 2);
      const speed = rand(1, 4);
      this.particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: CONFIG.PARTICLE_LIFE,
        maxLife: CONFIG.PARTICLE_LIFE,
        color: color,
        size: rand(2, 5)
      });
    }
  }

  // ==================== 游戏循环 ====================
  private startGameLoop(): void {
    if (this.gameTimer !== -1) {
      return;
    }
    this.gameTimer = setInterval(() => {
      this.update();
      this.draw();
    }, 32); // ~30fps
  }

  private stopGameLoop(): void {
    if (this.gameTimer !== -1) {
      clearInterval(this.gameTimer);
      this.gameTimer = -1;
    }
  }

  // ==================== 更新逻辑 ====================
  private update(): void {
    if (this.gameState !== GameState.PLAYING) {
      return;
    }
    this.frameCount++;

    // 更新玩家
    this.updatePlayer();
    // 更新小鱼
    this.updateSmallFishes();
    // 更新大鱼
    this.updateBigFishes();
    // 更新粒子
    this.updateParticles();
    // 更新气泡
    this.updateBubbles();
    // 碰撞检测
    this.checkCollisions();
  }

  private updatePlayer(): void {
    let moveX = 0;
    let moveY = 0;

    // 键盘/虚拟方向键控制
    if (this.keysDown.has('ArrowUp') || this.keysDown.has('w') || this.keysDown.has('W') || this.btnUpPressed) {
      moveY -= 1;
    }
    if (this.keysDown.has('ArrowDown') || this.keysDown.has('s') || this.keysDown.has('S') || this.btnDownPressed) {
      moveY += 1;
    }
    if (this.keysDown.has('ArrowLeft') || this.keysDown.has('a') || this.keysDown.has('A') || this.btnLeftPressed) {
      moveX -= 1;
    }
    if (this.keysDown.has('ArrowRight') || this.keysDown.has('d') || this.keysDown.has('D') || this.btnRightPressed) {
      moveX += 1;
    }

    // 触摸控制（优先级高于方向键）
    if (this.touchActive) {
      const dx = this.touchTargetX - this.player.x;
      const dy = this.touchTargetY - this.player.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist > 5) {
        moveX = dx / dist;
        moveY = dy / dist;
      }
    }

    // 归一化移动
    if (moveX !== 0 || moveY !== 0) {
      const len = Math.sqrt(moveX * moveX + moveY * moveY);
      moveX = moveX / len;
      moveY = moveY / len;
      this.player.targetAngle = Math.atan2(moveY, moveX);
    }

    // 平滑旋转
    this.player.angle = lerpAngle(this.player.angle, this.player.targetAngle, 0.15);

    // 移动
    const speed = CONFIG.PLAYER_SPEED;
    this.player.x += moveX * speed;
    this.player.y += moveY * speed;

    // 边界处理
    const halfSize = this.player.size;
    if (this.player.x < halfSize) {
      this.player.x = halfSize;
    }
    if (this.player.x > this.canvasWidth - halfSize) {
      this.player.x = this.canvasWidth - halfSize;
    }
    if (this.player.y < halfSize) {
      this.player.y = halfSize;
    }
    if (this.player.y > this.canvasHeight - halfSize) {
      this.player.y = this.canvasHeight - halfSize;
    }
  }

  private updateSmallFishes(): void {
    for (let i = 0; i < this.smallFishes.length; i++) {
      const fish = this.smallFishes[i];

      // 偶尔改变方向
      if (this.frameCount % 60 === i % 10) {
        fish.targetAngle = fish.angle + rand(-0.8, 0.8);
      }

      // 躲避玩家（如果玩家比较大）
      const dx = fish.x - this.player.x;
      const dy = fish.y - this.player.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const escapeDist = 120;
      if (dist < escapeDist && this.player.size > fish.size) {
        // 远离玩家
        fish.targetAngle = Math.atan2(dy, dx);
      }

      fish.angle = lerpAngle(fish.angle, fish.targetAngle, 0.05);

      // 移动
      const speed = CONFIG.SMALL_FISH_SPEED;
      fish.x += Math.cos(fish.angle) * speed;
      fish.y += Math.sin(fish.angle) * speed;

      // 边界反弹
      const margin = fish.size + 5;
      if (fish.x < margin || fish.x > this.canvasWidth - margin) {
        fish.targetAngle = Math.PI - fish.targetAngle;
        fish.x = fish.x < margin ? margin : this.canvasWidth - margin;
      }
      if (fish.y < margin || fish.y > this.canvasHeight - margin) {
        fish.targetAngle = -fish.targetAngle;
        fish.y = fish.y < margin ? margin : this.canvasHeight - margin;
      }
    }
  }

  private updateBigFishes(): void {
    for (let i = 0; i < this.bigFishes.length; i++) {
      const fish = this.bigFishes[i];

      // 大鱼的AI：有时追踪玩家，有时随机游动
      const dx = this.player.x - fish.x;
      const dy = this.player.y - fish.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < 200 && fish.size > this.player.size) {
        // 追踪玩家
        fish.targetAngle = Math.atan2(dy, dx);
      } else if (this.frameCount % 120 === i * 40) {
        // 随机改变方向
        fish.targetAngle = rand(0, Math.PI * 2);
      }

      fish.angle = lerpAngle(fish.angle, fish.targetAngle, 0.03);

      // 移动
      const speed = CONFIG.BIG_FISH_SPEED;
      fish.x += Math.cos(fish.angle) * speed;
      fish.y += Math.sin(fish.angle) * speed;

      // 环绕边界
      const margin = -fish.size * 2;
      const maxX = this.canvasWidth - margin;
      const maxY = this.canvasHeight - margin;
      if (fish.x < margin) {
        fish.x = maxX;
      }
      if (fish.x > maxX) {
        fish.x = margin;
      }
      if (fish.y < margin) {
        fish.y = maxY;
      }
      if (fish.y > maxY) {
        fish.y = margin;
      }
    }
  }

  private updateParticles(): void {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.08; // 重力
      p.life--;
      if (p.life <= 0) {
        this.particles.splice(i, 1);
      }
    }
  }

  private updateBubbles(): void {
    for (let i = 0; i < this.bubbles.length; i++) {
      const b = this.bubbles[i];
      b.y -= b.speed;
      b.x += Math.sin(this.frameCount * 0.02 + i) * 0.3;
      if (b.y < -b.radius) {
        b.y = this.canvasHeight + b.radius;
        b.x = rand(0, this.canvasWidth);
      }
    }
  }

  private checkCollisions(): void {
    // 玩家与小鱼碰撞
    for (let i = this.smallFishes.length - 1; i >= 0; i--) {
      const fish = this.smallFishes[i];
      const dx = this.player.x - fish.x;
      const dy = this.player.y - fish.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const collisionDist = (this.player.size + fish.size) * 0.6;

      if (dist < collisionDist) {
        if (this.player.size >= fish.size) {
          // 吃掉小鱼
          this.createParticles(fish.x, fish.y, fish.color);
          this.smallFishes.splice(i, 1);
          this.playerSize += CONFIG.SIZE_GROW;
          this.player.size = this.playerSize;
          this.score = Math.min(this.score + CONFIG.SCORE_PER_FISH, 300);
          if (this.score >= 300) {
            this.gameWin();
            return;
          }

          // 生成新小鱼
          this.smallFishes.push(this.createSmallFish());
        }
      }
    }

    // 玩家与大鱼碰撞
    for (let i = 0; i < this.bigFishes.length; i++) {
      const fish = this.bigFishes[i];
      const dx = this.player.x - fish.x;
      const dy = this.player.y - fish.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const collisionDist = (this.player.size + fish.size) * 0.55;

      if (dist < collisionDist) {
        if (this.player.size >= fish.size) {
          // 玩家够大，吃掉大鱼
          this.createParticles(fish.x, fish.y, fish.color);
          this.bigFishes.splice(i, 1);
          this.playerSize += CONFIG.SIZE_GROW * 3;
          this.player.size = this.playerSize;
          this.score = Math.min(this.score + CONFIG.SCORE_PER_FISH * 5, 300);
          if (this.score >= 300) {
            this.gameWin();
            return;
          }
          this.bigFishes.push(this.createBigFish());
        } else {
          // 游戏结束
          this.gameOver();
          return;
        }
      }
    }
  }

  // ==================== 游戏流程控制 ====================
  private startGame(): void {
    this.initGame();
    this.gameState = GameState.PLAYING;
    this.startGameLoop();
    // 主动触发一次绘制
    this.draw();
  }

  private gameOver(): void {
    this.gameState = GameState.OVER;
    this.stopGameLoop();
    this.createParticles(this.player.x, this.player.y, CONFIG.PLAYER_COLOR);
    this.createParticles(this.player.x, this.player.y, '#FFFFFF');
    this.createParticles(this.player.x, this.player.y, '#FFD700');
    // 绘制最后一帧
    this.draw();
  }

  private gameWin(): void {
    this.gameState = GameState.WIN;
    this.stopGameLoop();
    // 胜利粒子 - 金色烟花
    this.createParticles(this.player.x, this.player.y, '#FFD700');
    this.createParticles(this.player.x, this.player.y, '#FFD700');
    this.createParticles(this.player.x, this.player.y, '#FFA500');
    this.draw();
  }

  private restartGame(): void {
    this.stopGameLoop();
    this.initGame();
    this.gameState = GameState.PLAYING;
    this.startGameLoop();
  }

  // ==================== 绘制 ====================
  private draw(): void {
    const ctx = this.context;
    const w = this.canvasWidth;
    const h = this.canvasHeight;

    // 清空画布
    ctx.clearRect(0, 0, w, h);

    // 绘制背景渐变
    this.drawBackground(ctx, w, h);

    // 绘制水草
    this.drawSeaweeds(ctx, w, h);

    // 绘制气泡
    this.drawBubbles(ctx);

    // 绘制小鱼
    for (let i = 0; i < this.smallFishes.length; i++) {
      this.drawFish(ctx, this.smallFishes[i]);
    }

    // 绘制大鱼
    for (let i = 0; i < this.bigFishes.length; i++) {
      this.drawFish(ctx, this.bigFishes[i]);
    }

    // 绘制玩家
    if (this.gameState !== GameState.OVER) {
      this.drawFish(ctx, this.player);
      // 玩家光晕
      this.drawPlayerGlow(ctx);
    }

    // 绘制粒子
    this.drawParticles(ctx);

    // 绘制HUD
    this.drawHUD(ctx, w);

    // 绘制游戏状态覆盖层
    if (this.gameState === GameState.READY) {
      this.drawReadyOverlay(ctx, w, h);
    } else if (this.gameState === GameState.OVER) {
      this.drawGameOverOverlay(ctx, w, h);
    } else if (this.gameState === GameState.WIN) {
      this.drawWinOverlay(ctx, w, h);
    }
  }

  private drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    // 深海渐变背景
    const gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, CONFIG.WATER_COLOR_TOP);
    gradient.addColorStop(0.5, '#123456');
    gradient.addColorStop(1, CONFIG.WATER_COLOR_BOTTOM);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);

    // 光线效果
    for (let i = 0; i < 4; i++) {
      const lightX = w * (0.2 + i * 0.2);
      const lightGradient = ctx.createLinearGradient(lightX, 0, lightX + 40, h);
      lightGradient.addColorStop(0, 'rgba(255, 255, 255, 0.04)');
      lightGradient.addColorStop(0.5, 'rgba(255, 255, 255, 0.01)');
      lightGradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
      ctx.fillStyle = lightGradient;
      ctx.fillRect(lightX - 10, 0, 50, h);
    }
  }

  private drawSeaweeds(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    const seaweedCount = 6;
    for (let i = 0; i < seaweedCount; i++) {
      const baseX = w * (0.05 + i * 0.16);
      const baseY = h;
      const sway = Math.sin(this.frameCount * 0.03 + i * 1.5) * 8;

      ctx.save();
      ctx.beginPath();
      ctx.moveTo(baseX, baseY);

      const segments = 8;
      const segHeight = 40;
      for (let j = 0; j < segments; j++) {
        const cpX = baseX + sway * (j + 1) * 0.3 + Math.sin(j * 0.8 + this.frameCount * 0.02) * 12;
        const cpY = baseY - j * segHeight - segHeight / 2;
        const endX = baseX + sway * (j + 1) * 0.2;
        const endY = baseY - (j + 1) * segHeight;
        ctx.quadraticCurveTo(cpX, cpY, endX, endY);
      }

      ctx.lineWidth = 6 + i * 1.5;
      ctx.strokeStyle = hexToRgba('#1a6b3c', 0.6);
      ctx.lineCap = 'round';
      ctx.stroke();

      // 水草叶子
      const topX = baseX + sway * segments * 0.2;
      const topY = baseY - segments * segHeight;
      ctx.beginPath();
      ctx.moveTo(topX, topY);
      ctx.quadraticCurveTo(topX + sway + 15, topY - 20, topX + sway + 5, topY - 35);
      ctx.quadraticCurveTo(topX + sway - 5, topY - 15, topX, topY);
      ctx.fillStyle = hexToRgba('#2d8a4e', 0.5);
      ctx.fill();

      ctx.restore();
    }
  }

  private drawBubbles(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.bubbles.length; i++) {
      const b = this.bubbles[i];
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);

      const gradient = ctx.createRadialGradient(
        b.x - b.radius * 0.3, b.y - b.radius * 0.3, b.radius * 0.1,
        b.x, b.y, b.radius
      );
      gradient.addColorStop(0, `rgba(255, 255, 255, ${b.opacity + 0.15})`);
      gradient.addColorStop(1, `rgba(255, 255, 255, 0)`);
      ctx.fillStyle = gradient;
      ctx.fill();
    }
  }

  private drawFish(ctx: CanvasRenderingContext2D, fish: FishItem): void {
    const x = fish.x;
    const y = fish.y;
    const size = fish.size;
    const color = fish.color;
    const angle = fish.angle;
    const tailColor = fish.tailColor;

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);

    // 阴影
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowBlur = 4;
    ctx.shadowOffsetX = 2;
    ctx.shadowOffsetY = 2;

    // 身体（椭圆）
    ctx.beginPath();
    ctx.ellipse(0, 0, size * 0.8, size * 0.5, 0, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();

    // 清除阴影，避免尾巴被阴影影响
    ctx.shadowColor = 'transparent';
    ctx.shadowBlur = 0;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 0;

    // 尾巴
    ctx.beginPath();
    ctx.moveTo(-size * 0.55, 0);
    ctx.lineTo(-size * 1.15, -size * 0.45);
    ctx.lineTo(-size * 1.15, size * 0.45);
    ctx.closePath();
    ctx.fillStyle = tailColor;
    ctx.fill();
    ctx.strokeStyle = color;
    ctx.lineWidth = 1;
    ctx.stroke();

    // 背鳍
    ctx.beginPath();
    ctx.moveTo(-size * 0.1, -size * 0.45);
    ctx.quadraticCurveTo(size * 0.1, -size * 0.85, size * 0.3, -size * 0.15);
    ctx.fillStyle = tailColor;
    ctx.fill();

    // 胸鳍（下方）
    ctx.beginPath();
    ctx.moveTo(size * 0.05, size * 0.3);
    ctx.quadraticCurveTo(-size * 0.15, size * 0.75, -size * 0.35, size * 0.2);
    ctx.fillStyle = hexToRgba(tailColor, 0.7);
    ctx.fill();

    // 眼睛
    const eyeX = size * 0.45;
    const eyeY = -size * 0.1;
    const eyeR = size * 0.15;

    ctx.beginPath();
    ctx.arc(eyeX, eyeY, eyeR, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();

    ctx.beginPath();
    ctx.arc(eyeX + eyeR * 0.3, eyeY, eyeR * 0.55, 0, Math.PI * 2);
    ctx.fillStyle = '#111111';
    ctx.fill();

    // 眼睛高光
    ctx.beginPath();
    ctx.arc(eyeX + eyeR * 0.1, eyeY - eyeR * 0.25, eyeR * 0.2, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();

    // 鱼鳃线
    ctx.beginPath();
    ctx.moveTo(size * 0.15, -size * 0.3);
    ctx.quadraticCurveTo(size * 0.35, 0, size * 0.15, size * 0.3);
    ctx.strokeStyle = hexToRgba(tailColor, 0.5);
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.restore();
  }

  private drawPlayerGlow(ctx: CanvasRenderingContext2D): void {
    // 玩家鱼的光晕效果
    ctx.save();
    const glowSize = this.player.size * 1.6;
    const gradient = ctx.createRadialGradient(
      this.player.x, this.player.y, this.player.size * 0.4,
      this.player.x, this.player.y, glowSize
    );
    gradient.addColorStop(0, 'rgba(255, 200, 100, 0.25)');
    gradient.addColorStop(0.5, 'rgba(255, 150, 50, 0.08)');
    gradient.addColorStop(1, 'rgba(255, 100, 0, 0)');
    ctx.beginPath();
    ctx.arc(this.player.x, this.player.y, glowSize, 0, Math.PI * 2);
    ctx.fillStyle = gradient;
    ctx.fill();
    ctx.restore();
  }

  private drawParticles(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      const alpha = p.life / p.maxLife;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size * alpha, 0, Math.PI * 2);
      ctx.fillStyle = hexToRgba(p.color, alpha);
      ctx.fill();
    }
  }

  private drawHUD(ctx: CanvasRenderingContext2D, w: number): void {
    // 半透明顶部背景
    ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.fillRect(0, 0, w, 50);

    // 分数
    ctx.font = 'bold 22px sans-serif';
    ctx.fillStyle = '#FFFFFF';
    ctx.textAlign = 'left';
    ctx.fillText(`🐟 分数: ${this.score}`, 16, 34);

    // 体型
    ctx.font = '16px sans-serif';
    ctx.fillStyle = '#FFD700';
    ctx.textAlign = 'right';
    ctx.fillText(`体型: ${this.playerSize}`, w - 16, 34);
  }

  private drawReadyOverlay(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    // 半透明遮罩
    ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
    ctx.fillRect(0, 0, w, h);

    // 标题
    ctx.font = 'bold 36px sans-serif';
    ctx.fillStyle = '#FFD700';
    ctx.textAlign = 'center';
    ctx.fillText('🐟 大鱼吃小鱼 🐟', w / 2, h / 2 - 60);

    // 说明
    ctx.font = '18px sans-serif';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText('吃掉比你小的鱼来成长', w / 2, h / 2 - 10);
    ctx.fillText('躲开比你大的鱼！', w / 2, h / 2 + 20);

    // 提示
    ctx.font = '14px sans-serif';
    ctx.fillStyle = '#AAAAAA';
    ctx.fillText('点击"开始游戏"或按空格键', w / 2, h / 2 + 60);
  }

  private drawGameOverOverlay(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    // 半透明遮罩
    ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
    ctx.fillRect(0, 0, w, h);

    // 游戏结束文字
    ctx.font = 'bold 40px sans-serif';
    ctx.fillStyle = '#FF4444';
    ctx.textAlign = 'center';
    ctx.fillText('游戏结束', w / 2, h / 2 - 40);

    // 最终分数
    ctx.font = 'bold 28px sans-serif';
    ctx.fillStyle = '#FFD700';
    ctx.fillText(`最终分数: ${this.score}`, w / 2, h / 2 + 15);

    // 体型
    ctx.font = '20px sans-serif';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(`最终体型: ${this.playerSize}`, w / 2, h / 2 + 50);

    // 重新开始提示
    ctx.font = '16px sans-serif';
    ctx.fillStyle = '#AAAAAA';
    ctx.fillText('点击"重新开始"继续游戏', w / 2, h / 2 + 90);
  }

  private drawWinOverlay(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    // 半透明遮罩
    ctx.fillStyle = 'rgba(0, 0, 0, 0.65)';
    ctx.fillRect(0, 0, w, h);

    // 胜利标题
    ctx.font = 'bold 42px sans-serif';
    ctx.fillStyle = '#FFD700';
    ctx.textAlign = 'center';
    ctx.fillText('🎉 胜利！ 🎉', w / 2, h / 2 - 60);

    // 祝贺
    ctx.font = 'bold 22px sans-serif';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText('你是这片海洋的王者！', w / 2, h / 2 - 10);

    // 最终分数
    ctx.font = 'bold 26px sans-serif';
    ctx.fillStyle = '#FFD700';
    ctx.fillText(`最终分数: ${this.score}`, w / 2, h / 2 + 30);

    // 提示
    ctx.font = '16px sans-serif';
    ctx.fillStyle = '#AAAAAA';
    ctx.fillText('点击"再来一局"继续称霸', w / 2, h / 2 + 70);
  }

  // ==================== UI 布局 ====================
  build() {
    Column() {
      // 游戏 Canvas
      Stack() {
        Canvas(this.context)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.canvasWidth = this.context.width;
            this.canvasHeight = this.context.height;
            this.initGame();
            this.draw();
          })
          .onAreaChange((_: Area, newArea: Area) => {
            const w = newArea.width as number;
            const h = newArea.height as number;
            if (w > 0 && h > 0 && (w !== this.canvasWidth || h !== this.canvasHeight)) {
              this.canvasWidth = w;
              this.canvasHeight = h;
              this.initGame();
              if (this.gameState === GameState.PLAYING) {
                this.draw();
              }
            }
          })
          .onTouch((event: TouchEvent) => {
            if (this.gameState !== GameState.PLAYING) {
              return;
            }
            switch (event.type) {
              case TouchType.Down:
              case TouchType.Move:
                if (event.touches.length > 0) {
                  this.touchActive = true;
                  this.touchTargetX = event.touches[0].x;
                  this.touchTargetY = event.touches[0].y;
                }
                break;
              case TouchType.Up:
              case TouchType.Cancel:
                this.touchActive = false;
                break;
            }
          })
          .focusable(true)
          .onKeyEvent((event: KeyEvent) => {
            if (event.type === KeyType.Down) {
              this.keysDown.add(event.keyCode.toString());
              // 空格键开始/重新开始
              if (event.keyCode === 2054) {
                if (this.gameState === GameState.READY) {
                  this.startGame();
                } else if (this.gameState === GameState.OVER) {
                  this.restartGame();
                } else if (this.gameState === GameState.WIN) {
                  this.restartGame();
                }
              }
              return true;
            } else if (event.type === KeyType.Up) {
              this.keysDown.delete(event.keyCode.toString());
              return true;
            }
            return false;
          })

        // 游戏状态按钮（开始/重新开始）
        if (this.gameState === GameState.READY) {
          Button('🎮 开始游戏')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF6B35')
            .borderRadius(30)
            .padding({
              left: 40,
              right: 40,
              top: 14,
              bottom: 14
            })
            .shadow({ radius: 10, color: '#FF6B3540' })
            .position({ x: '50%', y: '65%' })
            .translate({ x: '-50%', y: 0 })
            .onClick(() => {
              this.startGame();
            })
        }

        if (this.gameState === GameState.OVER) {
          Button('🔄 重新开始')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#E74C3C')
            .borderRadius(30)
            .padding({
              left: 40,
              right: 40,
              top: 14,
              bottom: 14
            })
            .shadow({ radius: 10, color: '#E74C3C40' })
            .position({ x: '50%', y: '70%' })
            .translate({ x: '-50%', y: 0 })
            .onClick(() => {
              this.restartGame();
            })
        }

        if (this.gameState === GameState.WIN) {
          Button('🏆 再来一局')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#FFD700')
            .borderRadius(30)
            .padding({
              left: 40,
              right: 40,
              top: 14,
              bottom: 14
            })
            .shadow({ radius: 10, color: '#FFD70040' })
            .position({ x: '50%', y: '70%' })
            .translate({ x: '-50%', y: 0 })
            .onClick(() => {
              this.restartGame();
            })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#0a1a2e')

      // 虚拟方向键
      if (this.gameState === GameState.PLAYING) {
        this.buildDirectionPad()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildDirectionPad() {
    Column() {
      // 上方：上按钮
      Button('▲')
        .fontSize(24)
        .fontColor('#FFFFFF')
        .backgroundColor('#FFFFFF20')
        .borderRadius(12)
        .width(60)
        .height(50)
        .onTouch((event: TouchEvent) => {
          this.btnUpPressed = event.type === TouchType.Down;
        })

      Row({ space: 16 }) {
        // 左按钮
        Button('◀')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .backgroundColor('#FFFFFF20')
          .borderRadius(12)
          .width(60)
          .height(50)
          .onTouch((event: TouchEvent) => {
            this.btnLeftPressed = event.type === TouchType.Down;
          })

        // 下按钮
        Button('▼')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .backgroundColor('#FFFFFF20')
          .borderRadius(12)
          .width(60)
          .height(50)
          .onTouch((event: TouchEvent) => {
            this.btnDownPressed = event.type === TouchType.Down;
          })

        // 右按钮
        Button('▶')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .backgroundColor('#FFFFFF20')
          .borderRadius(12)
          .width(60)
          .height(50)
          .onTouch((event: TouchEvent) => {
            this.btnRightPressed = event.type === TouchType.Down;
          })
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 20 })
    .backgroundColor('#0d2238')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}