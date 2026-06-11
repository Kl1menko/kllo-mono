<?php
/**
 * Завантажувач СТАТИЧНИХ медіа для CDN.
 * Приймає будь-який файл (avif, svg, mp4, mp3, woff2, ttf, png, jpg, webp)
 * і кладе його БЕЗ ОБРОБКИ за вказаним відносним шляхом усередині assets/.
 *
 * Розмістити на сервері як:  cdn/api/upload-static.php
 * Тоді файли лягають у:      cdn/assets/<path>
 * Публічний URL:             https://cdn.kllo.com.ua/assets/<path>
 * (папка cdn/ роздається через субдомен cdn.kllo.com.ua)
 *
 * Запит:
 *   POST multipart/form-data
 *   Заголовок: X-API-Key: <ключ>
 *   Поля:  file = <бінарний файл>
 *          path = "img/logo-kllo.svg"   (відносний шлях усередині assets/)
 */

header('Content-Type: application/json; charset=utf-8');

$apiKey = 'qNylSvdfy3aneryxEou0KXapnsZUoLPj4bFEZMvfnPU';

function fail(int $code, string $msg, array $extra = []): void {
    http_response_code($code);
    echo json_encode(array_merge(['success' => false, 'message' => $msg], $extra),
        JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

$headers = function_exists('getallheaders') ? getallheaders() : [];
$token = $headers['X-API-Key'] ?? $headers['x-api-key'] ?? '';
if (!hash_equals($apiKey, $token)) {
    fail(401, 'Unauthorized');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    fail(405, 'Method not allowed');
}

if (empty($_FILES['file'])) {
    fail(400, 'No file uploaded (field "file")');
}

$file = $_FILES['file'];
if ($file['error'] !== UPLOAD_ERR_OK) {
    fail(400, 'Upload error', ['code' => $file['error']]);
}

$maxSize = 50 * 1024 * 1024; // 50 MB (під відео)
if ($file['size'] > $maxSize) {
    fail(400, 'File is too large');
}

// --- Дозволені розширення (статичні медіа сайту) ---
$allowedExt = ['avif','svg','png','jpg','jpeg','webp','gif','mp4','webm','mp3','wav','ogg','woff','woff2','ttf','otf','ico','webmanifest'];

// --- Валідація відносного шляху (захист від path traversal) ---
$relPath = $_POST['path'] ?? '';
$relPath = str_replace('\\', '/', $relPath);
$relPath = ltrim($relPath, '/');

if ($relPath === '' || strpos($relPath, '..') !== false || strpos($relPath, "\0") !== false) {
    fail(400, 'Invalid path');
}
// дозволяємо лише безпечні символи у сегментах
if (!preg_match('#^[A-Za-z0-9._/-]+$#', $relPath)) {
    fail(400, 'Path contains forbidden characters');
}

$ext = strtolower(pathinfo($relPath, PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExt, true)) {
    fail(400, 'Extension not allowed: ' . $ext);
}

// --- Базова папка: cdn/assets/ (скрипт лежить у cdn/api/) ---
$assetsRoot = realpath(__DIR__ . '/..') . '/assets';
$targetPath = $assetsRoot . '/' . $relPath;

// Переконуємось, що цільовий шлях НЕ вийшов за межі assets/
$targetDir = dirname($targetPath);
if (!is_dir($targetDir) && !mkdir($targetDir, 0775, true) && !is_dir($targetDir)) {
    fail(500, 'Failed to create directory');
}
$resolvedDir = realpath($targetDir);
if ($resolvedDir === false || strpos($resolvedDir, $assetsRoot) !== 0) {
    fail(400, 'Path escapes assets root');
}

if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    fail(500, 'Failed to move file');
}
@chmod($targetPath, 0644);

echo json_encode([
    'success' => true,
    'path'    => 'assets/' . $relPath,
    'url'     => '/assets/' . $relPath,
    'size'    => filesize($targetPath),
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
