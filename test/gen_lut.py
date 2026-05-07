import math

print('Circular:')
for i in range(10):
    val = int(round(math.atan(2**-i) * 1024))
    print(f"4'd{i}: lut_value = 12'h{val:03X};")

print('\nHyperbolic:')
for i in range(1, 11):
    val = int(round(math.atanh(2**-i) * 1024))
    print(f"4'd{i}: lut_value = 12'h{val:03X};")
