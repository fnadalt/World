#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import argparse
import os
import os.path
import sys
import configparser
import re
import numpy
import noise
import math
import png

# topography constants
TopoDataFileName = "topography.npy"
TopoImageFileName = "topography.png"
TopoTypeRegular = "regular"
TopoTypeValley = "valley"
TopoTypeIsland = "island"

# temperature constants
TempDataFileName = "temperature.npy"
TempImageFileName = "temperature.png"
TempTypeNoise = "noise"
TempTypeElevation = "elevation"
TempTypeDistCtr = "dist_ctr"  # distance to center
TempTypeElevDistCtr = "elevation_dist_ctr"  # elevation and distance to center

# humidity constants
HumidityDataFileName = "humidity.npy"
HumidityImageFileName = "humidity.png"
HumidityTypeNoise = "noise"
HumidityTypeElevation = "elevation"

# noise constants
NoiseDataFileName = "noise.npy"
NoiseImageFileName = "noise.png"

# terrain constants (terrain5.png)
TerrGrassY = 0
TerrMtn0 = 1
TerrMtnWhite = 2
TerrIce = 3
TerrCracked = 4
TerrDry = 5
TerrMud = 6
TerrMudCracked = 7
TerrMtnDesert = 8
TerrMtnDry = 9
TerrMtnGreen = 10
TerrMtnDark = 11
TerrDesert = 12
TerrGrassDry = 13
TerrGrass = 14
TerrSnow = 15

# terrain constants (terrain7.png)
Terr7MtnWhite = 0
Terr7MtnIce = 1
Terr7DryDirt = 2
Terr7WetDirt = 3
Terr7DryGrass = 4
Terr7WetGrass = 5
Terr7Snow = 6
Terr7Sand = 7
Terr7TempSnowTransitionStart = 0.30
Terr7TempSnowTransitionEnd = 0.35
Terr7TempSandTransitionStart = 0.85
Terr7TempSandTransitionEnd = 0.9
Terr7HumidityBlendStart = 0.45
Terr7HumidityBlendEnd = 0.55

# data images
THNImageFileName = "land_data_thn.png"
BLDImageFileName = "land_data_bld.png"
ALPHAImageFileName0 = "land_data_alpha0.png"
ALPHAImageFileName1 = "land_data_alpha1.png"

# slopes
SlopesImageFileName = "slopes.png"
SlopeTransitionStart = 0.05
SlopeTransitionEnd = 0.085

# normals
NormalsDataFileName = "normals.npy"

# default config dict
_defaul_config={"global": {
                            "name":"land",
                            "size_total":512,
                            "ocean_altitude":0.1  # [0.0, 1.0]
                            },
                "topography": {
                            "type":TopoTypeRegular,
                            "change_distances":"0.80 0.95",
                            "perlin_seed":"0.634",
                            "perlin_layer_0":"256.0 1.0"
                            },
                "temperature": {
                            "type":"elevation",
                            "perlin_seed":"0.156",
                            "perlin_layer_0":"1024.0 1.0"
                            },
                "humidity": {
                            "type":"elevation",
                            "perlin_seed":"0.456",
                            "perlin_layer_0":"512.0 1.0"
                            },
                "noise": {
                            "perlin_seed":"0.159",
                            "perlin_layer_0":"256.0 1.0",
                            "perlin_layer_1":"128.0 0.5",
                            "perlin_layer_2":"64.0 0.25",
                            "perlin_layer_3":"32.0 0.125",
                            "perlin_layer_4":"16.0 0.03125",
                            "perlin_layer_5":"8.0 0.015625",
                            "perlin_layer_6":"4.0 0.0078125",
                            "perlin_layer_7":"2.0 0.00390625"
                            }
                }

#
config = None
directory = "."
size_total = 2
noise_horiz_scale = 1
ocean_altitude = 0.1

def delete_file(file_path):
    if not os.path.exists(file_path):
        return True
    logging.warning("%s exists, it will be deleted" % file_path)
    try:
        os.remove(file_path)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def progress(n, N):
    p = 100 * n / N
    sys.stdout.write("%.2f%%\r" % p)

def normalize(array):
    logging.info("normalize array")
    valmin, valmax = array.min(), array.max()
    amp = 1 if valmax == 0 else 1 / (valmax - valmin)
    for x in range(size_total):
        for y in range(size_total):
            value = array[x][y]
            value -= valmin
            value *= amp
            array[x][y] = value
        progress(x, size_total)

def histogram(array):
    logging.info("histogram:")
    values, bins = numpy.histogram(array, bins=10)
    values = values / values.max()
    print(str(str(values) + " " + str(bins)))

def get_altitude(topography, x, y, scale):
    _x, _y = x, y
    if x < 0:
        _x = 0
    if x >= size_total:
        _x = size_total - 1
    if y < 0:
        _y = 0
    if y >= size_total:
        _y = size_total - 1
    return topography[_x][_y] * scale

def calculate_normal(v0, v1, v2):
    U = numpy.subtract(v1, v0)
    V = numpy.subtract(v2, v0)
    return numpy.cross(U, V)

def generate_slopes_data(normals):
    logging.info("generating slopes data...")
    size = normals.shape[0]
    slopes = numpy.zeros((size, size), dtype=numpy.float)
    for x in range(size):
        for y in range(size):
            slope = abs(numpy.dot(normals[x][y], (0, 1, 0)))
            slopes[x][y] = slope
        progress(x, size_total)
    histogram(slopes)
    return slopes

def load_data(file_name):
    #
    file_path = os.path.join(directory, file_name)
    #
    try:
        if os.path.exists(file_path):
            logging.info("load data from file: " + file_path)
            array = numpy.load(file_path)
            return array
    except Exception as e:
        logging.exception(str(e))
        return numpy.array(0)

def do_topography(size, noise_array):
    logging.info("generate topography data file")
    file_path = os.path.join(directory, TopoDataFileName)
    # type
    type = config['topography'].get('type')
    logging.info("topography type: " + type)
    # change normalized distances
    change_dist_start, change_dist_end = config['topography'].get('change_distances').split()
    change_dist_start, change_dist_end = float(change_dist_start), float(change_dist_end)
    # perlin noise seed
    seed = config['topography'].getfloat('perlin_seed')
    # perlin noise layers
    layers = list()
    i_layer = 0
    try:
        while i_layer >= 0:
            var_name = "perlin_layer_%i" % i_layer
            if var_name in config['topography']:
                freq, amp = config['topography'].get(var_name).split()
                layers.append((float(freq), float(amp)))
                i_layer += 1
                continue
            i_layer = -1
    except Exception as e:
        logging.exception(str(e))
        return False
    # delete file
    if not delete_file(file_path):
        return False
    # array
    array = numpy.zeros((size, size), dtype=numpy.float)
    # normalizer divisor for perlin levels amplitudes
    amp_normalizer = 0.0
    for freq, amp in layers:
        amp_normalizer += amp
    # generate data
    logging.info("generate regular topography data")
    repeat = 1024
    for x in range(size_total):
        for y in range(size_total):
            value = 0.0
            # for each perlin level
            for freq, amp in layers:
                freq *= noise_horiz_scale
                value += amp * noise.snoise2(x / freq, y / freq, 1, 0.5, 2.0, repeatx=repeat, repeaty=repeat, base=seed)
            value /= amp_normalizer
            value = (value * 0.5) + 0.5
            array[x][y] = value
        progress(x, size_total)
    # type
    if type == TopoTypeValley or type == TopoTypeIsland:
        logging.info("shape topography data to type " + type)
        for x in range(size_total):
            for y in range(size_total):
                _x, _y = ((x / size_total) * 2) - 1, ((y / size_total) * 2) - 1
                dist_to_center = math.sqrt(_x ** 2 + _y ** 2)
                value = array[x][y]
                if dist_to_center > change_dist_end:
                    value = 1.0 if type==TopoTypeValley else 0.0
                    array[x][y] = value
                elif dist_to_center > change_dist_start:
                    if type == TopoTypeValley:
                        value += (1.0 - value) * ((dist_to_center - change_dist_start) / (change_dist_end - change_dist_start))
                    elif type == TopoTypeIsland:
                        value -= value * ((dist_to_center - change_dist_start) / (change_dist_end - change_dist_start))
                    array[x][y] = value
                elif dist_to_center < change_dist_start:
                    if type == TopoTypeIsland:
                        value += 1.4 * value * (1.0 - dist_to_center / change_dist_start)
            progress(x, size_total)
    # modulate altitude
    logging.info("modulate topography data")
    for x in range(size_total):
        for y in range(size_total):
            altitude = array[x][y]
            d = altitude - ocean_altitude
            altitude = ocean_altitude + (d / abs(d)) * math.pow(d, 2)
            # ~ altitude += 0.333 * noise_array[x][y]
            array[x][y] = altitude
        progress(x, size_total)
    # normalize
    normalize(array)
    # histogram
    histogram(array)
    # write array
    logging.info("save topography file: " + file_path)
    try:
        numpy.save(file_path, array)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def do_normals(topography):
    logging.info("generate normals data file")
    file_path = os.path.join(directory, NormalsDataFileName)
    # delete file
    if not delete_file(file_path):
        return False
    # array
    array = numpy.zeros(topography.shape, dtype=tuple)
    # generate data
    logging.info("generate normals data")
    for x in range(size_total):
        for y in range(size_total):
            v0 = (x, get_altitude(topography, x, y, 255), y)
            v1 = (x + 1, get_altitude(topography, x + 1, y, 255), y)
            v2 = (x, get_altitude(topography, x, y + 1, 255), y + 1)
            v3 = (x + 1, get_altitude(topography, x + 1, y - 1, 255), y - 1)
            v4 = (x - 1, get_altitude(topography, x - 1, y + 1, 255), y + 1)
            v5 = (x - 1, get_altitude(topography, x - 1, y, 255), y)
            v6 = (x, get_altitude(topography, x, y - 1, 255), y - 1)
            n0 = calculate_normal(v0, v1, v2)
            n1 = calculate_normal(v0, v3, v1)
            n2 = calculate_normal(v0, v2, v4)
            n3 = calculate_normal(v0, v5, v6)
            n = (n0 + n1 + n2 + n3) / 4
            n /= numpy.linalg.norm(n)
            array[x][y] = n
        progress(x, size_total)
    # write array
    logging.info("save normals file: " + file_path)
    try:
        numpy.save(file_path, array)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def do_temperature(topography):
    logging.info("generate temperature data file")
    file_path = os.path.join(directory, TempDataFileName)
    # type
    type = config['temperature'].get('type')
    # perlin noise seed
    seed = config['temperature'].getfloat('perlin_seed')
    # perlin noise layers
    layers = list()
    i_layer = 0
    try:
        while i_layer >= 0:
            var_name = "perlin_layer_%i" % i_layer
            if var_name in config['temperature']:
                freq, amp = config['temperature'].get(var_name).split()
                layers.append((float(freq), float(amp)))
                i_layer += 1
                continue
            i_layer = -1
    except Exception as e:
        logging.exception(str(e))
        return False
    # delete file
    if not delete_file(file_path):
        return False
    # array
    array = numpy.zeros(topography.shape, dtype=numpy.float)
    # normalizer divisor for perlin levels amplitudes
    amp_normalizer = 0.0
    for freq, amp in layers:
        amp_normalizer += amp
    # generate data
    logging.info("generate temperature data, type=" + type)
    if type == TempTypeNoise:
        repeat = 1024
        for x in range(size_total):
            for y in range(size_total):
                value = 0.0
                # for each perlin level
                for freq, amp in layers:
                    freq *= noise_horiz_scale
                    value += amp * noise.snoise2(x / freq, y / freq, 1, 0.5, 2.0, repeatx=repeat, repeaty=repeat, base=seed)
                value /= amp_normalizer
                value = (value * 0.5) + 0.5
                array[x][y] = value
            progress(x, size_total)
    elif type == TempTypeElevation or type == TempTypeElevDistCtr:
        for x in range(size_total):
            for y in range(size_total):
                value = 1.0 - topography[x][y]
                array[x][y] = value
            progress(x, size_total)
    elif type == TempTypeDistCtr:
        for x in range(size_total):
            for y in range(size_total):
                array[x][y] = 1.0
            progress(x, size_total)
    # apply topography data
    logging.info("apply topography data to temperature")
    for x in range(size_total):
        for y in range(size_total):
            value = array[x][y]
            # distance to ocean
            if type == TempTypeNoise or type == TempTypeElevation or type == TempTypeElevDistCtr:
                altitude = topography[x][y]
                distance_to_ocean = 0.0
                if altitude > ocean_altitude:
                    distance_to_ocean = (altitude - ocean_altitude) / (1.0 - ocean_altitude)
                else:
                    distance_to_ocean = 0.0  # 1.0 - altitude / ocean_altitude
                value -= 0.2 * distance_to_ocean
            # distance to center
            if type == TempTypeNoise or type == TempTypeDistCtr or type == TempTypeElevDistCtr:
                _x, _y = 2.0 * (0.5 - x / size_total), 2.0 * (0.5 - y / size_total)
                dist_to_center = min(1.0, math.sqrt(_x ** 2 + _y ** 2))
                value *= 1.25 * (1.0 - dist_to_center)
            #
            value = max(0.0, min(1.0, value))
            array[x][y] = value
        progress(x, size_total)
    # normalize
    normalize(array)
    # histogram
    histogram(array)
    # write array
    logging.info("save temperature file: " + file_path)
    try:
        numpy.save(file_path, array)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def do_humidity(topography):
    logging.info("generate humidity data file")
    file_path = os.path.join(directory, HumidityDataFileName)
    # type
    type = config['humidity'].get('type')
    # perlin noise seed
    seed = config['humidity'].getfloat('perlin_seed')
    # perlin noise layers
    layers = list()
    i_layer = 0
    try:
        while i_layer >= 0:
            var_name = "perlin_layer_%i" % i_layer
            if var_name in config['humidity']:
                freq, amp = config['humidity'].get(var_name).split()
                layers.append((float(freq), float(amp)))
                i_layer += 1
                continue
            i_layer = -1
    except Exception as e:
        logging.exception(str(e))
        return False
    # delete file
    if not delete_file(file_path):
        return False
    # array
    array = numpy.zeros(topography.shape, dtype=numpy.float)
    # normalizer divisor for perlin levels amplitudes
    amp_normalizer = 0.0
    for freq, amp in layers:
        amp_normalizer += amp
    # generate data
    logging.info("generate humidity data, type=" + type)
    if type == HumidityTypeNoise:
        repeat = 1024
        for x in range(size_total):
            for y in range(size_total):
                value = 0.0
                # for each perlin level
                for freq, amp in layers:
                    value += amp * noise.snoise2(x / freq, y / freq, 1, 0.5, 2.0, repeatx=repeat, repeaty=repeat, base=seed)
                value /= amp_normalizer
                value = (value * 0.5) + 0.5
                array[x][y] = value
            progress(x, size_total)
    elif type == HumidityTypeElevation:
        for x in range(size_total):
            for y in range(size_total):
                value = 1.0 - topography[x][y]
                array[x][y] = value
            progress(x, size_total)
    # apply topography data
    # ~ if type == HumidityTypeNoise:
        # ~ logging.info("apply topography data to humidity")
        # ~ for x in range(size_total):
            # ~ for y in range(size_total):
                # ~ value = array[x][y]
                # ~ # distance to ocean
                # ~ altitude = topography[x][y]
                # ~ distance_to_ocean = 0.0
                # ~ if altitude > ocean_altitude:
                    # ~ distance_to_ocean = (altitude - ocean_altitude) / (1.0 - ocean_altitude)
                # ~ else:
                    # ~ distance_to_ocean = 0.0
                # ~ value -= 0.99 * distance_to_ocean
                # ~ value = max(0.0, value)
                # ~ #
                # ~ array[x][y] = value
            # ~ progress(x, size_total)
    # normalize
    normalize(array)
    # histogram
    histogram(array)
    # write array
    logging.info("save humidity file: " + file_path)
    try:
        numpy.save(file_path, array)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def do_noise():
    logging.info("generate noise data file")
    file_path = os.path.join(directory, NoiseDataFileName)
    # perlin noise seed
    seed = config['noise'].getfloat('perlin_seed')
    # perlin noise layers
    layers = list()
    i_layer = 0
    try:
        while i_layer >= 0:
            var_name = "perlin_layer_%i" % i_layer
            if var_name in config['noise']:
                freq, amp = config['noise'].get(var_name).split()
                layers.append((float(freq), float(amp)))
                i_layer += 1
                continue
            i_layer = -1
    except Exception as e:
        logging.exception(str(e))
        return False
    # delete file
    if not delete_file(file_path):
        return False
    # array
    array = numpy.zeros((size_total, size_total), dtype=numpy.float)
    # normalizer divisor for perlin levels amplitudes
    amp_normalizer = 0.0
    for freq, amp in layers:
        amp_normalizer += amp
    # generate data
    logging.info("generate noise data")
    repeat = 32
    for x in range(size_total):
        for y in range(size_total):
            value = 0.0
            # for each perlin level
            for freq, amp in layers:
                value += amp * noise.snoise2(x / freq, y / freq, 1, 0.5, 2.0, repeatx=repeat, repeaty=repeat, base=seed)
            value /= amp_normalizer
            value = (value * 0.5) + 0.5
            array[x][y] = value
        progress(x, size_total)
    # normalize
    normalize(array)
    # histogram
    histogram(array)
    # write array
    logging.info("save noise file: " + file_path)
    try:
        numpy.save(file_path, array)
    except Exception as e:
        logging.exception(str(e))
        return False
    return True

def do_image(array_data, file_name):
    #
    file_path = os.path.join(directory, file_name)
    logging.info("generate image: " + file_path)
    # delete file
    if not delete_file(file_path):
        return False
    #
    if len(array_data) == 0:
        log.error("no data")
        return False
    #
    array_pxl = numpy.zeros(array_data.shape, dtype=numpy.uint8)
    #
    size = array_data.shape[0]
    for x in range(size):
        for y in range(size):
            value = array_data[x][y]
            value *= int(255)
            array_pxl[x][y] = value
        progress(x, size_total)
    # histogram
    histogram(array_pxl)
    #
    png.from_array(array_pxl, "L;8").save(file_path)
    return True

def do_pack_image_thn(normals, temperature, humidity, noise_array):
    #
    file_name = THNImageFileName
    file_path = os.path.join(directory, file_name)
    logging.info("generate packed image for temperature, humidity and noise: " + file_path)
    # delete file
    if not delete_file(file_path):
        return False
    #
    size = temperature.shape[0]
    array_pxl = numpy.zeros((size, size * 4), dtype=numpy.uint8)
    #
    slopes = generate_slopes_data(normals)
    #
    logging.info("generating image data...")
    for x in range(size):
        for y in range(size):
            y_shft = 4 * y
            value0 = temperature[x][y]
            value0 *= int(255)
            value1 = calculate_bld_factor(humidity[x][y], slopes[x][y])
            value1 *= int(255)
            value2 = slopes[x][y]
            value2 *= int(255)
            value3 = noise_array[x][y]
            value3 *= int(255)
            array_pxl[x][y_shft + 0] = value0
            array_pxl[x][y_shft + 1] = value1
            array_pxl[x][y_shft + 2] = value2
            array_pxl[x][y_shft + 3] = value3
        progress(x, size_total)
    # histogram
    histogram(array_pxl)
    #
    png.from_array(array_pxl, "RGBA").save(file_path)
    return True

def do_pack_image_bld(topography, normals, temperature, humidity, noise_array):
    #
    file_name = BLDImageFileName
    file_path = os.path.join(directory, file_name)
    logging.info("generate packed image for terrain indices, blend factor and noise: " + file_path)
    # delete file
    if not delete_file(file_path):
        return False
    #
    size = topography.shape[0]
    array_pxl = numpy.zeros((size, size * 4), dtype=numpy.uint8)
    #
    slopes = generate_slopes_data(normals)
    #
    logging.info("generating image pixels...")
    for x in range(size):
        for y in range(size):
            y_shft = 4 * y
            #
            indices, blend_factor = calculate_data_bld(topography[x][y], slopes[x][y], temperature[x][y], humidity[x][y])
            adj_noise = noise_array[x][y]
            adj_noise *= int(255)
            array_pxl[x][y_shft + 0] = indices
            array_pxl[x][y_shft + 1] = blend_factor
            array_pxl[x][y_shft + 2] = int(255) * slopes[x][y]
            array_pxl[x][y_shft + 3] = adj_noise
        progress(x, size_total)
    #
    png.from_array(array_pxl, "RGBA").save(file_path)
    return True

def calculate_data_bld(altitude, slope, temperature, humidity):
    indices, blend_factor = 0, 0
    #
    if temperature < 0.20:
        indices = calculate_bld_indices(TerrMudCracked, TerrSnow, TerrMtnDark, slope)
    elif temperature < 0.40:
        indices = calculate_bld_indices(TerrDry, TerrGrassDry, TerrMtnDry, slope)
    elif temperature < 0.60:
        indices = calculate_bld_indices(TerrDry, TerrGrassY, TerrMtnDesert, slope)
    elif temperature < 0.80:
        indices = calculate_bld_indices(TerrMud, TerrGrass, TerrMtnGreen, slope)
    elif temperature <= 1.00:
        if humidity < 0.6:
            indices = calculate_bld_indices(TerrCracked, TerrDesert, TerrMtnDesert, slope)
        else:
            indices = calculate_bld_indices(TerrMud, TerrGrass, TerrMtnDesert, slope)
    else:
        logging.error("calculate_data_bld: unexpected shit, altitude=%.2f slope=%.2f temperature=%.2f humidity=%.2f" % (altitude, slope, temperature, humidity))
    #
    blend_factor = calculate_bld_factor(humidity, slope)
    #
    adj_blend_factor = int(255  * blend_factor)
    #
    # ~ logging.debug("> %s %s | %i" % (str(bin(idx0)), str(bin(idx1)), factor))
    return indices, adj_blend_factor

def calculate_bld_indices(terrain_lower, terrain_upper, terrain_vertical, slope):
    if slope > SlopeTransitionStart:
        indices = int(terrain_lower * 16 + terrain_upper)
    else:
        indices = int(terrain_vertical * 16 + terrain_lower)
    return indices

def calculate_bld_factor(humidity, slope):
    if slope < SlopeTransitionStart:
        blend_factor = 0.0
    elif slope > SlopeTransitionEnd:
        blend_factor = (humidity + 1.0) / 2.0
    else:
        blend_factor = (humidity + ((slope - SlopeTransitionStart) / (SlopeTransitionEnd - SlopeTransitionStart))) / 2.0
    blend_factor = (humidity + slope) / 2;  # !!!
    return blend_factor

def do_pack_image_alpha(topography, normals, temperature, humidity, noise_array):
    #
    file_name0 = ALPHAImageFileName0
    file_name1 = ALPHAImageFileName1
    file_path0 = os.path.join(directory, file_name0)
    file_path1 = os.path.join(directory, file_name1)
    logging.info("generate 2 blend maps: %s and %s" % (file_path0, file_path1))
    # delete file2
    if not delete_file(file_path0):
        return False
    if not delete_file(file_path1):
        return False
    #
    size = topography.shape[0]
    array_pxl0 = numpy.zeros((size, size * 4), dtype=numpy.uint8)
    array_pxl1 = numpy.zeros((size, size * 4), dtype=numpy.uint8)
    #
    slopes = generate_slopes_data(normals)
    #
    logging.info("generating images pixels...")
    for x in range(size):
        for y in range(size):
            y_shft = 4 * y
            #
            data = calculate_data_alpha(topography[x][y], slopes[x][y], temperature[x][y], humidity[x][y], noise_array[x][y])
            array_pxl0[x][y_shft + 0] = data[0]
            array_pxl0[x][y_shft + 1] = data[1]
            array_pxl0[x][y_shft + 2] = data[2]
            array_pxl0[x][y_shft + 3] = data[3]
            array_pxl1[x][y_shft + 0] = data[4]
            array_pxl1[x][y_shft + 1] = data[5]
            array_pxl1[x][y_shft + 2] = data[6]
            array_pxl1[x][y_shft + 3] = data[7]
        progress(x, size_total)
    #
    png.from_array(array_pxl0, "RGBA").save(file_path0)
    png.from_array(array_pxl1, "RGBA").save(file_path1)
    return True

def calculate_data_alpha(altitude, slope, temperature, humidity, noise):
    #
    data = numpy.array(8 * [0], dtype=numpy.float)
    beach_altitude = ocean_altitude + 0.05
    hum_blend = calculate_blend(humidity, Terr7HumidityBlendStart, Terr7HumidityBlendEnd)
    slope_blend = calculate_blend(slope, SlopeTransitionStart, SlopeTransitionEnd)
    temp_blend = 0.0
    #
    if altitude < beach_altitude:
        temp_blend = calculate_blend(temperature, Terr7TempSnowTransitionStart, Terr7TempSnowTransitionEnd)
        data[Terr7Sand] = temp_blend
        data[Terr7Snow] = (1.0 - temp_blend)
    else:
        if temperature < Terr7TempSnowTransitionStart:
            data[Terr7Snow] = 1.0
        elif temperature > Terr7TempSandTransitionEnd:
            data[Terr7Sand] = 1.0
        else:
            noise_blend = calculate_blend(noise, 0.4, 0.6)
            data[Terr7DryDirt] = (1.0 - hum_blend) * noise_blend
            data[Terr7WetDirt] = hum_blend * noise_blend
            data[Terr7DryGrass] = (1.0 - hum_blend) * (1.0 - noise_blend)
            data[Terr7WetGrass] = hum_blend * (1.0 - noise_blend)
            if temperature > Terr7TempSnowTransitionStart and temperature < Terr7TempSnowTransitionEnd:
                temp_blend = calculate_blend(temperature, Terr7TempSnowTransitionStart, Terr7TempSnowTransitionEnd)
                data = data * temp_blend
                data[Terr7Snow] = 1.0 - temp_blend
            elif temperature > Terr7TempSandTransitionStart and temperature < Terr7TempSandTransitionEnd:
                temp_blend = calculate_blend(temperature, Terr7TempSandTransitionStart, Terr7TempSandTransitionEnd)
                data = data * temp_blend
                data[Terr7Sand] = temp_blend
            #
            if slope_blend < 1.0:
                data = data * slope_blend
                temp_blend = calculate_blend(temperature, Terr7TempSnowTransitionStart, Terr7TempSnowTransitionEnd)
                data[Terr7MtnIce] = (1.0 - temp_blend)
                data[Terr7MtnWhite] = temp_blend
    #
    if numpy.sum(data) == 0.0:
        logging.error("no blend data: %s; a=%.2f s=%.2f t=%.2f h=%.2f n=%.2f t_bld=%.2f h_bld=%.2f s_bld=%.2f" % (str(data), altitude, slope, temperature, humidity, noise, temp_blend, hum_blend, slope_blend))
    return 255 * data

def calculate_blend(value, lower_bound, upper_bound):
    if value < lower_bound:
        return 0.0
    elif value > upper_bound:
        return 1.0
    else:
        return (value - lower_bound) / (upper_bound  - lower_bound)

def do_slopes_image(normals):
    logging.info("generate slopes image file")
    file_path = os.path.join(directory, SlopesImageFileName)
    # delete file
    if not delete_file(file_path):
        return False
    #
    if len(normals) == 0:
        log.error("no normals data")
        return False
    #
    array_pxl = numpy.zeros(normals.shape, dtype=numpy.uint8)
    #
    size = normals.shape[0]
    for x in range(size):
        for y in range(size):
            normal = normals[x][y]
            # ~ normal /= numpy.linalg.norm(normal)
            value = int(abs(numpy.dot(normal, (0, 1, 0))) * 255)
            array_pxl[x][y] = value
        progress(x, size_total)
    # histogram
    histogram(array_pxl)
    #
    png.from_array(array_pxl, "L;8").save(file_path)
    return True

def execute():
    print("Land Creator")
    global config, directory, size_total, noise_horiz_scale, ocean_altitude
    # log
    logging.basicConfig(level=logging.DEBUG)
    # arguments parsing
    argp = argparse.ArgumentParser()
    argp.add_argument('land_file', help='land description file')
    argp.add_argument('-d', '--debug', action='store_true', help='logging.level=logging.DEBUG')
    argp.add_argument('-t', '--topography', action='store_true', help='generate topography data file')
    argp.add_argument('-i', '--topography_image', action='store_true', help='generate topography image')
    argp.add_argument('-e', '--temperature', action='store_true', help='generate temperature data file')
    argp.add_argument('-p', '--temperature_image', action='store_true', help='generate temperature image file')
    argp.add_argument('-u', '--humidity', action='store_true', help='generate humidity data file')
    argp.add_argument('-m', '--humidity_image', action='store_true', help='generate humidity image file')
    argp.add_argument('-n', '--noise', action='store_true', help='generate noise data file')
    argp.add_argument('-o', '--noise_image', action='store_true', help='generate noise image file')
    argp.add_argument('-k', '--pack_images_thn', action='store_true', help='pack temperature, humidity and noise into RGB in image file')
    argp.add_argument('-b', '--pack_images_bld', action='store_true', help='pack terrain blend data into RGBA in image file')
    argp.add_argument('-a', '--pack_images_alpha', action='store_true', help='generate 2 alpha blend maps')
    argp.add_argument('-r', '--normals', action='store_true', help='generate normals data file')
    argp.add_argument('-l', '--slopes_image', action='store_true', help='generate slopes image file')
    args = argp.parse_args()
    # land file
    land_file_path = args.land_file
    if not os.path.exists(land_file_path) or not os.path.isfile(land_file_path):
        land_file_path += ".ini"
        if not os.path.exists(land_file_path):
            logging.error("land file does not exist: " + land_file_path)
            sys.exit()
    #
    logging.info("file: " + land_file_path)
    config = configparser.ConfigParser()
    config.read_dict(_defaul_config)
    try:
        config.read(land_file_path)
    except Exception as e:
        logging.exception(str(e))
        sys.exit()
    # name
    land_name = config["global"].get("name")
    logging.info("land name: " + land_name)
    if not re.match("[_a-zA-Z][_a-zA-Z0-9]*", land_name):
        logging.error("characters allowed for name are alphanumeric and underscore")
        sys.exit()
    # directory
    if not os.path.exists(land_name):
        logging.info("directory does not exist, create...")
        try:
            os.mkdir(land_name)
        except Exception as e:
            logging.exception(str(e))
            sys.exit()
    directory = land_name
    # size
    size_total = config['global'].getint('size_total')
    size_verified = math.pow(2, int(math.log2(size_total))) + 1
    if size_total != size_verified:
        logging.warning("size must be a power-of-two plus one number, got %i and will de adjusted to %i" % (size_total, size_verified))
        size_total = int(size_verified)
    # noise horizontal scale
    noise_horiz_scale = config['global'].getfloat('noise_horiz_scale')
    # ocean height
    ocean_altitude = config['global'].getfloat('ocean_altitude')
    # noise
    if args.noise:
        if not do_noise():
            sys.exit()
    noise_array = load_data(NoiseDataFileName)
    # topography
    if args.topography:
        if not do_topography(size_total, noise_array):
            sys.exit()
    topography = load_data(TopoDataFileName)
    # normals
    if args.normals:
        if not do_normals(topography):
            sys.exit()
    normals = load_data(NormalsDataFileName)
    # slopes
    if args.slopes_image:
        if not do_slopes_image(normals):
            sys.exit()
    # topography image
    if args.topography_image:
        if not do_image(topography, TopoImageFileName):
            sys.exit()
    # temperature
    if args.temperature:
        if not do_temperature(topography):
            sys.exit()
    temperature = load_data(TempDataFileName)
    # temperature image
    if args.temperature_image:
        if not do_image(temperature, TempImageFileName):
            sys.exit()
    # humidity
    if args.humidity:
        if not do_humidity(topography):
            sys.exit()
    humidity = load_data(HumidityDataFileName)
    # humidity image
    if args.humidity_image:
        if not do_image(humidity, HumidityImageFileName):
            sys.exit()
    # noise image
    if args.noise_image:
        if not do_image(noise_array, NoiseImageFileName):
            sys.exit()
    # pack temperature, humidity and noise data into image
    if args.pack_images_thn:
        if not do_pack_image_thn(normals, temperature, humidity, noise_array):
            sys.exit()
    # pack terrain indices, blend factor and noise into image
    if args.pack_images_bld:
        if not do_pack_image_bld(topography, normals, temperature, humidity, noise_array):
            sys.exit()
    # generate 2 alpha blend maps
    if args.pack_images_alpha:
        if not do_pack_image_alpha(topography, normals, temperature, humidity, noise_array):
            sys.exit()

if __name__ == "__main__":
    execute()
