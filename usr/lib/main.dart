import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// MAIN ENTRY POINT & UI OVERLAYS
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set full screen and landscape for immersive experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameLauncher(),
  ));
}

class GameLauncher extends StatefulWidget {
  const GameLauncher({super.key});

  @override
  State<GameLauncher> createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  late ShadowRunnerGame _game;

  @override
  void initState() {
    super.initState();
    _game = ShadowRunnerGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'MainMenu': (context, ShadowRunnerGame game) => MainMenuOverlay(game: game),
          'GameOver': (context, ShadowRunnerGame game) => GameOverOverlay(game: game),
          'HUD': (context, ShadowRunnerGame game) => GameHUD(game: game),
        },
        initialActiveOverlays: const ['MainMenu'],
      ),
    );
  }
}

// ==========================================
// UI WIDGETS
// ==========================================

class MainMenuOverlay extends StatelessWidget {
  final ShadowRunnerGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SHADOW RUNNER',
              style: GoogleFonts.pressStart2d(
                fontSize: 40,
                color: Colors.cyanAccent,
                shadows: [const Shadow(blurRadius: 10, color: Colors.blue)],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ADVENTURE',
              style: GoogleFonts.pressStart2d(
                fontSize: 24,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(height: 50),
            _buildButton(
              label: 'START GAME',
              color: Colors.green,
              onPressed: () {
                game.startGame();
              },
            ),
            const SizedBox(height: 20),
            _buildButton(
              label: 'SHOP (Coming Soon)',
              color: Colors.orange,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({required String label, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixel art style
      ),
      child: Text(
        label,
        style: GoogleFonts.vt323(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final ShadowRunnerGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'YOU DIED',
              style: GoogleFonts.pressStart2d(fontSize: 50, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              'Score: ${game.score}',
              style: GoogleFonts.vt323(fontSize: 40, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                game.resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.pressStart2d(fontSize: 20, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameHUD extends StatelessWidget {
  final ShadowRunnerGame game;

  const GameHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (context, score, child) {
                return Text(
                  'SCORE: $score',
                  style: GoogleFonts.vt323(fontSize: 35, color: Colors.white),
                );
              },
            ),
            Row(
              children: [
                const Icon(Icons.diamond, color: Colors.cyan, size: 30),
                const SizedBox(width: 5),
                ValueListenableBuilder<int>(
                  valueListenable: game.coinsNotifier,
                  builder: (context, coins, child) {
                    return Text(
                      '$coins',
                      style: GoogleFonts.vt323(fontSize: 35, color: Colors.white),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// GAME ENGINE LOGIC (FLAME)
// ==========================================

class ShadowRunnerGame extends FlameGame with TapDetector, VerticalDragDetector, HorizontalDragDetector, HasCollisionDetection {
  late PlayerComponent player;
  late LevelGenerator levelGenerator;
  
  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> coinsNotifier = ValueNotifier(0);
  
  int score = 0;
  int coins = 0;
  double speed = 200.0;
  bool isGameOver = false;
  bool isPlaying = false;

  @override
  Future<void> onLoad() async {
    // Background
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF1a1a2e), // Dark Forest Blue
    ));
    
    // Stars/Particles (Simple implementation)
    for(int i=0; i<50; i++) {
      add(StarComponent(size));
    }

    // Player
    player = PlayerComponent();
    
    // Level Generator
    levelGenerator = LevelGenerator();
  }

  void startGame() {
    if (isPlaying) return;
    
    overlays.remove('MainMenu');
    overlays.add('HUD');
    
    resetGameData();
    
    // Add components
    add(player..position = Vector2(100, size.y - 150));
    add(levelGenerator);
    
    isPlaying = true;
    isGameOver = false;
    resumeEngine();
  }

  void resetGame() {
    overlays.remove('GameOver');
    removeAll(children.whereType<PlatformComponent>());
    removeAll(children.whereType<EnemyComponent>());
    removeAll(children.whereType<CoinComponent>());
    
    resetGameData();
    
    player.position = Vector2(100, size.y - 150);
    player.velocity = Vector2.zero();
    player.reset();
    
    isPlaying = true;
    isGameOver = false;
    resumeEngine();
  }

  void resetGameData() {
    score = 0;
    coins = 0;
    speed = 250.0;
    scoreNotifier.value = 0;
    coinsNotifier.value = 0;
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;
    isPlaying = false;
    pauseEngine();
    overlays.add('GameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isPlaying) return;

    // Increase score based on time/distance
    score += (dt * 10).toInt();
    scoreNotifier.value = score;

    // Increase speed gradually
    if (speed < 600) {
      speed += dt * 5;
    }
  }

  // --- INPUT HANDLING ---

  @override
  void onTapDown(TapDownInfo info) {
    if (isPlaying) player.jump();
  }

  @override
  void onVerticalDragEnd(DragEndInfo info) {
    if (!isPlaying) return;
    if (info.velocity.y < -100) {
      // Swipe Up
      player.doubleJump();
    } else if (info.velocity.y > 100) {
      // Swipe Down
      player.smash();
    }
  }

  @override
  void onHorizontalDragEnd(DragEndInfo info) {
    if (!isPlaying) return;
    if (info.velocity.x > 100) {
      // Swipe Right
      player.dash();
    }
  }
}

// ==========================================
// COMPONENTS
// ==========================================

class PlayerComponent extends PositionComponent with HasGameRef<ShadowRunnerGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  final double gravity = 1000.0;
  final double jumpForce = -550.0;
  
  bool isOnGround = false;
  bool canDoubleJump = false;
  bool isDashing = false;
  double dashTimer = 0;

  PlayerComponent() : super(size: Vector2(40, 40), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Pixel Art Knight Placeholder
    final paint = Paint()..color = isDashing ? Colors.cyanAccent : Colors.grey;
    canvas.drawRect(size.toRect(), paint);
    
    // Visor
    canvas.drawRect(Rect.fromLTWH(20, 10, 15, 5), Paint()..color = Colors.redAccent);
    
    // Scarf
    canvas.drawRect(Rect.fromLTWH(-5, 15, 10, 5), Paint()..color = Colors.red);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gravity
    velocity.y += gravity * dt;

    // Dash Logic
    if (isDashing) {
      dashTimer -= dt;
      if (dashTimer <= 0) {
        isDashing = false;
        velocity.x = 0; // Stop horizontal dash
      } else {
        velocity.y = 0; // Defy gravity while dashing
      }
    }

    // Apply movement
    position += velocity * dt;

    // Ground Floor (Safety Net)
    if (position.y > gameRef.size.y - 50) {
      position.y = gameRef.size.y - 50;
      velocity.y = 0;
      isOnGround = true;
      canDoubleJump = true;
    } else {
      // Simple check if we fell off screen
      if (position.y > gameRef.size.y + 100) {
        gameRef.gameOver();
      }
    }
  }

  void jump() {
    if (isOnGround) {
      velocity.y = jumpForce;
      isOnGround = false;
      canDoubleJump = true;
    }
  }

  void doubleJump() {
    if (canDoubleJump && !isOnGround) {
      velocity.y = jumpForce * 0.9;
      canDoubleJump = false;
      // Spawn particle effect here ideally
    }
  }

  void smash() {
    if (!isOnGround) {
      velocity.y = 1000; // Fast fall
    }
  }

  void dash() {
    if (!isDashing) {
      isDashing = true;
      dashTimer = 0.2; // 200ms dash
      // In a real runner, we might not move X, but instead make us invincible or destroy enemies
    }
  }
  
  void reset() {
    velocity = Vector2.zero();
    isOnGround = false;
    isDashing = false;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    
    if (other is PlatformComponent) {
      // Simple top collision check
      if (velocity.y > 0 && position.y + size.y / 2 <= other.position.y - other.size.y / 2 + 10) {
        velocity.y = 0;
        position.y = other.position.y - other.size.y / 2 - size.y / 2;
        isOnGround = true;
        canDoubleJump = true;
      }
    } else if (other is EnemyComponent) {
      if (isDashing) {
        other.removeFromParent(); // Kill enemy
        gameRef.score += 50;
      } else {
        gameRef.gameOver();
      }
    } else if (other is CoinComponent) {
      other.removeFromParent();
      gameRef.coinsNotifier.value++;
      gameRef.score += 10;
    }
  }
}

// ==========================================
// WORLD GENERATION
// ==========================================

class LevelGenerator extends Component with HasGameRef<ShadowRunnerGame> {
  double spawnTimer = 0;
  double nextSpawnTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    spawnTimer += dt;

    if (spawnTimer >= nextSpawnTime) {
      spawnPlatform();
      spawnTimer = 0;
      nextSpawnTime = Random().nextDouble() * 1.5 + 0.8; // Random spawn interval
    }
  }

  void spawnPlatform() {
    final double yPos = gameRef.size.y - 50 - Random().nextInt(150).toDouble();
    final double width = 100.0 + Random().nextInt(100);
    
    // Spawn Platform
    final platform = PlatformComponent(
      position: Vector2(gameRef.size.x + 50, yPos),
      size: Vector2(width, 20),
    );
    gameRef.add(platform);

    // Chance to spawn Enemy
    if (Random().nextDouble() < 0.3) {
      gameRef.add(EnemyComponent(
        position: Vector2(gameRef.size.x + 50 + Random().nextInt(50), yPos - 40),
      ));
    }

    // Chance to spawn Coin
    if (Random().nextDouble() < 0.5) {
      gameRef.add(CoinComponent(
        position: Vector2(gameRef.size.x + 50 + Random().nextInt(50), yPos - 50 - Random().nextInt(50)),
      ));
    }
  }
}

class PlatformComponent extends PositionComponent with HasGameRef<ShadowRunnerGame> {
  PlatformComponent({required Vector2 position, required Vector2 size}) 
      : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Pixel Art Platform
    final paint = Paint()..color = const Color(0xFF5d4037); // Brown
    canvas.drawRect(size.toRect(), paint);
    
    // Grass top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 5), Paint()..color = const Color(0xFF388e3c));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= gameRef.speed * dt;

    if (position.x < -size.x) {
      removeFromParent();
    }
  }
}

class EnemyComponent extends PositionComponent with HasGameRef<ShadowRunnerGame> {
  EnemyComponent({required Vector2 position}) 
      : super(position: position, size: Vector2(30, 30), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Slime or Bat placeholder
    canvas.drawRect(size.toRect(), Paint()..color = Colors.purple);
    // Eyes
    canvas.drawRect(Rect.fromLTWH(5, 5, 5, 5), Paint()..color = Colors.yellow);
    canvas.drawRect(Rect.fromLTWH(20, 5, 5, 5), Paint()..color = Colors.yellow);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= (gameRef.speed + 50) * dt; // Move slightly faster than platforms

    if (position.x < -size.x) {
      removeFromParent();
    }
  }
}

class CoinComponent extends PositionComponent with HasGameRef<ShadowRunnerGame> {
  CoinComponent({required Vector2 position}) 
      : super(position: position, size: Vector2(20, 20), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), 10, Paint()..color = Colors.amber);
    canvas.drawCircle(Offset(size.x/2, size.y/2), 6, Paint()..color = Colors.yellowAccent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= gameRef.speed * dt;
    
    // Bobbing animation
    position.y += sin(gameRef.currentTime() * 5) * 0.5;

    if (position.x < -size.x) {
      removeFromParent();
    }
  }
}

class StarComponent extends PositionComponent with HasGameRef<ShadowRunnerGame> {
  late double speed;
  
  StarComponent(Vector2 screenSize) {
    position = Vector2(
      Random().nextDouble() * screenSize.x,
      Random().nextDouble() * screenSize.y,
    );
    size = Vector2(2, 2);
    speed = Random().nextDouble() * 50 + 10;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = Colors.white.withOpacity(0.5));
  }

  @override
  void update(double dt) {
    position.x -= speed * dt;
    if (position.x < 0) {
      position.x = gameRef.size.x;
      position.y = Random().nextDouble() * gameRef.size.y;
    }
  }
}
