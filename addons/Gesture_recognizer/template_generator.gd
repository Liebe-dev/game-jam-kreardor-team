@tool
extends Node

# Hàm tạo vòng tròn hoàn hảo (Hệ Nước)
func generate_circle(radius: float = 100.0, points_count: int = 64) -> Array:
	var points = []
	for i in range(points_count + 1):
		var angle = (float(i) / points_count) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

# Hàm tạo tam giác đều (Hệ Lửa)
func generate_triangle(size: float = 100.0) -> Array:
	return [
		Vector2(0, -size),          # Đỉnh trên
		Vector2(size, size),        # Đỉnh dưới phải
		Vector2(-size, size),       # Đỉnh dưới trái
		Vector2(0, -size)           # Quay lại đỉnh để đóng hình
	]

# Hàm tạo ô vuông (Hệ Đất)
func generate_square(size: float = 100.0) -> Array:
	return [
		Vector2(-size, -size),
		Vector2(size, -size),
		Vector2(size, size),
		Vector2(-size, size),
		Vector2(-size, -size)
	]
