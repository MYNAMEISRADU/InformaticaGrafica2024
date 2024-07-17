shader_type canvas_item;
uniform int radius;

void fragment() {
	ivec2 texel = ivec2(FRAGCOORD.xy);
	
	vec4 mean_of_squared_color_of_quadrants[4] = vec4[](vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));
	vec4 mean_of_color_of_quadrants[4] = vec4[](vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));
	
	for (int q = 0; q < 4; q++) {
		ivec2 sign = ivec2((q % 2) * 2 - 1, ((q / 2) * 2 - 1));
		
		ivec2 lower_bound = texel - ivec2(sign.x > 0 ? 0 : radius, sign.y > 0 ? 0 : radius);
		ivec2 upper_bound = texel + ivec2(sign.x < 0 ? 0 : radius, sign.y < 0 ? 0 : radius);
		
		ivec2 image_bound = textureSize(TEXTURE, 0) - ivec2(1);
		ivec2 corrected_lower_bound = min(image_bound, max(ivec2(0), lower_bound));
		ivec2 corrected_upper_bound = min(image_bound, max(ivec2(0), upper_bound));
		ivec2 region_size = corrected_upper_bound - corrected_lower_bound + ivec2(1);
		int quadrant_pixel_count = region_size.x * region_size.y;
		
		for (int j = 0; j <= radius; j++) {
			for (int i = 0; i <= radius; i++) {
				vec4 color = texelFetch(TEXTURE, texel + ivec2(i, j) * sign, 0);
				mean_of_color_of_quadrants[q] += color;
				mean_of_squared_color_of_quadrants[q] += color * color;
			}
		}
		mean_of_color_of_quadrants[q] /= float(quadrant_pixel_count);
		mean_of_squared_color_of_quadrants[q] /= float(quadrant_pixel_count);
	}
	
	float minimum_variance;
	vec4 mean_color_of_chosen_quadrant = mean_of_color_of_quadrants[0];
	for (int q = 0; q < 4; q++) {
		vec4 color_mean = mean_of_color_of_quadrants[q];
		vec4 squared_color_mean = mean_of_squared_color_of_quadrants[q];
		vec4 color_variance = squared_color_mean - color_mean * color_mean;
		
		float variance = dot(color_variance.rgb, vec3(1.0));
		if (variance < minimum_variance) {
			minimum_variance = variance;
			mean_color_of_chosen_quadrant = color_mean;
		}
	}
	
	COLOR = mean_color_of_chosen_quadrant;
}