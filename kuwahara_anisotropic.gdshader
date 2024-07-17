shader_type canvas_item;

uniform float eccentricity = 8;
uniform float radius = 4;
uniform float sharpness = 8;

float square(float a) {
	return a*a;
}

vec2 vsquare(vec2 a) {
	return a*a;
}

void fragment() {
	const float gradient_corner_weight = 0.182;
	const float gradient_center_weight = 1.0 - 2.0 * gradient_corner_weight;
	ivec2 uv;
	uv = ivec2(FRAGCOORD.xy);
	
	vec3 x_partial_derivative = texelFetch(TEXTURE, uv + ivec2(-1, 1), 0).rgb * -gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(-1, 0), 0).rgb * -gradient_center_weight +
	                            texelFetch(TEXTURE, uv + ivec2(-1, -1), 0).rgb * -gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(1, 1), 0).rgb * gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(1, 0), 0).rgb * gradient_center_weight +
	                            texelFetch(TEXTURE, uv + ivec2(1, -1), 0).rgb * gradient_corner_weight;
	
	vec3 y_partial_derivative = texelFetch(TEXTURE, uv + ivec2(-1, 1), 0).rgb * gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(0, 1), 0).rgb * gradient_center_weight +
	                            texelFetch(TEXTURE, uv + ivec2(1, 1), 0).rgb * gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(-1, -1), 0).rgb * -gradient_corner_weight +
	                            texelFetch(TEXTURE, uv + ivec2(0, -1), 0).rgb * -gradient_center_weight +
	                            texelFetch(TEXTURE, uv + ivec2(1, -1), 0).rgb * -gradient_corner_weight;

	float dxdx = dot(x_partial_derivative, x_partial_derivative);
	float dxdy = dot(x_partial_derivative, y_partial_derivative);
	float dydy = dot(y_partial_derivative, y_partial_derivative);
	
	vec4 structure_tensor = vec4(dxdx, dxdy, dxdy, dydy) * 3.0;
	
	COLOR = structure_tensor;
	
	float eigenvalue_first_term = (dxdx + dydy) / 2.0;
	float eigenvalue_square_root_term = sqrt(square(dxdx - dydy) + 4.0 * square(dxdy)) / 2.0;
	float first_eigenvalue = eigenvalue_first_term + eigenvalue_square_root_term;
	float second_eigenvalue = eigenvalue_first_term - eigenvalue_square_root_term;
	
	vec2 eigenvector = vec2(first_eigenvalue - dxdx, -dxdy);
	float eigenvector_length = length(eigenvector);
	vec2 unit_eigenvector = eigenvector_length != 0.0 ? eigenvector / eigenvector_length : vec2(1.0);
	
	float eigenvalue_sum = first_eigenvalue + second_eigenvalue;
	float eigenvalue_difference = first_eigenvalue - second_eigenvalue;
	float anisotropy = eigenvalue_sum > 0.0 ? eigenvalue_difference / eigenvalue_sum : 0.0;
	
	float ellipse_width_factor = eccentricity / (eccentricity + anisotropy);
	float ellipse_width = ellipse_width_factor * radius;
	float ellipse_height = radius / ellipse_width_factor;
	
	float cosine = unit_eigenvector.x;
	float sine = unit_eigenvector.y;
	
	mat2 inverse_ellipse_matrix = mat2(vec2(cosine / ellipse_width,
	                                   -sine / ellipse_height),
	                                    vec2(sine / ellipse_width,
	                                    cosine / ellipse_height));
	
	vec2 ellipse_major_axis = ellipse_width * unit_eigenvector;
	vec2 ellipse_minor_axis = ellipse_height * unit_eigenvector.yx * vec2(-1, 1);
	ivec2 ellipse_bounds = ivec2(ceil(sqrt(vsquare(ellipse_major_axis) + vsquare(ellipse_minor_axis))));
	
	const int number_of_sectors = 8;
	float sector_center_overlap_parameter = 2.0 / radius;
	float sector_envelope_angle = ((3.0 / 2.0) * PI) / float(number_of_sectors);
	float cross_sector_overlap_parameter = (sector_center_overlap_parameter +
	                                         cos(sector_envelope_angle)) /
	                                         square(sin(sector_envelope_angle));
	
	vec4 weighted_mean_of_squared_color_of_sectors[8];
	vec4 weighted_mean_of_color_of_sectors[8];
	float sum_of_weights_of_sectors[8];
	
	vec4 center_color = texelFetch(TEXTURE, uv, 0);
	vec4 center_color_squared = center_color * center_color;
	float center_weight = 1.0 / float(number_of_sectors);
	vec4 weighted_center_color = center_color * center_weight;
	vec4 weighted_center_color_squared = center_color_squared * center_weight;
	
	for (int i = 0; i < number_of_sectors; i++) {
		weighted_mean_of_squared_color_of_sectors[i] = weighted_center_color_squared;
		weighted_mean_of_color_of_sectors[i] = weighted_center_color;
		sum_of_weights_of_sectors[i] = center_weight;
	}
	
	for (int j = 0; j <= ellipse_bounds.y; j++) {
		for (int i = -ellipse_bounds.x; i <= ellipse_bounds.x; i++) {
			
			if (j == 0 && i <= 0) {
			continue;
			}
			
			vec2 disk_point = inverse_ellipse_matrix * vec2(float(i), float(j));
			float disk_point_length_squared = dot(disk_point, disk_point);
			if (disk_point_length_squared > 1.0) {
				continue;
			}
			
			float sector_weights[8];
			
			vec2 polynomial = sector_center_overlap_parameter - cross_sector_overlap_parameter * vsquare(disk_point);
			sector_weights[0] = square(max(0.0, disk_point.y + polynomial.x));
			sector_weights[2] = square(max(0.0, -disk_point.x + polynomial.y));
			sector_weights[4] = square(max(0.0, -disk_point.y + polynomial.x));
			sector_weights[6] = square(max(0.0, disk_point.x + polynomial.y));
			
			vec2 rotated_disk_point = 1.0/sqrt(2.0) * vec2(disk_point.x - disk_point.y, disk_point.x + disk_point.y);
			
			vec2 rotated_polynomial = sector_center_overlap_parameter - cross_sector_overlap_parameter * vsquare(rotated_disk_point);
			sector_weights[1] = square(max(0.0, rotated_disk_point.y + rotated_polynomial.x));
			sector_weights[3] = square(max(0.0, -rotated_disk_point.x + rotated_polynomial.y));
			sector_weights[5] = square(max(0.0, -rotated_disk_point.y + rotated_polynomial.x));
			sector_weights[7] = square(max(0.0, rotated_disk_point.x + rotated_polynomial.y));
			
			float sector_weights_sum = sector_weights[0] + sector_weights[1] + sector_weights[2] + sector_weights[3] + sector_weights[4] + 
			                           sector_weights[5] + sector_weights[6] + sector_weights[7];
			
			float radial_gaussian_weight = exp(-3.0 * disk_point_length_squared);
			
			vec4 upper_color = texelFetch(TEXTURE, uv + ivec2(i, j), 0);
			vec4 lower_color = texelFetch(TEXTURE, uv - ivec2(i, j), 0);
			vec4 upper_color_squared = upper_color * upper_color;
			vec4 lower_color_squared = lower_color * lower_color;
			
			for (int k = 0; k < number_of_sectors; k++) {
				
				float weight = sector_weights[k] * radial_gaussian_weight;
				
				int upper_index = k;
				sum_of_weights_of_sectors[upper_index] += weight;
				weighted_mean_of_color_of_sectors[upper_index] += upper_color * weight;
				weighted_mean_of_squared_color_of_sectors[upper_index] += upper_color_squared * weight;
				
				int lower_index = (k + number_of_sectors / 2) % number_of_sectors;
				sum_of_weights_of_sectors[lower_index] += weight;
				weighted_mean_of_color_of_sectors[lower_index] += lower_color * weight;
				weighted_mean_of_squared_color_of_sectors[lower_index] += lower_color_squared * weight;
			}
		}
	}
	float sum_of_weights = 0.0;
	vec4 weighted_sum = vec4(0.0);
	for (int i = 0; i < number_of_sectors; i++) {
		weighted_mean_of_color_of_sectors[i] /= sum_of_weights_of_sectors[i];
		weighted_mean_of_squared_color_of_sectors[i] /= sum_of_weights_of_sectors[i];
		
		vec4 color_mean = weighted_mean_of_color_of_sectors[i];
		vec4 squared_color_mean = weighted_mean_of_squared_color_of_sectors[i];
		vec4 color_variance = abs(squared_color_mean - color_mean * color_mean);
		
		float standard_deviation = dot(sqrt(color_variance.rgb), vec3(1.0));
		
		float weight = 1.0 / pow(max(0.02, standard_deviation), sharpness);
		
		sum_of_weights += weight;
		weighted_sum += color_mean * weight;
	}
	weighted_sum /= sum_of_weights;
	
	COLOR = weighted_sum;
}