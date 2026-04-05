import serial
import numpy as np
import struct
import matplotlib.pyplot as plt
from scipy.signal import correlate2d

def binary_digit_by_digit_sqrt(n: int, precision: int = 8):
    if n < 0:
        raise ValueError("Broj mora biti nenegativan.")
    if n == 0:
        return 0.0, "0." + "0" * precision

    bin_n = bin(n)[2:]
    if len(bin_n) % 2 != 0:
        bin_n = "0" + bin_n

    pairs = [bin_n[i:i+2] for i in range(0, len(bin_n), 2)]
    pairs += ["00"] * precision

    res_bits = []
    rem = 0
    P = 0

    for par in pairs:
        rem = (rem << 2) | int(par, 2)
        test = (P << 2) | 1  # 4P+1

        if test <= rem:
            res_bits.append("1")
            rem -= test
            P = (P << 1) | 1
        else:
            res_bits.append("0")
            P = (P << 1)

    int_len = len(bin_n) // 2
    int_part = "".join(res_bits[:int_len]).lstrip("0") or "0"
    frac_part = "".join(res_bits[int_len:])
    return P / (2 ** precision), f"{int_part}.{frac_part}"

def load_bits(path: str, n: int) -> np.ndarray:
    vals = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if s:
                vals.append(int(s, 2))
            if len(vals) == n:
                break
    if len(vals) != n:
        raise ValueError(f"{path}: ocekujem {n} piksela, nasao {len(vals)}")
    return np.array(vals, dtype=np.uint8)

def read_exact(ser: serial.Serial, nbytes: int) -> bytes:
    """Cita tacno nbytes ili baca TimeoutError."""
    data = bytearray()
    while len(data) < nbytes:
        chunk = ser.read(nbytes - len(data))
        if not chunk:
            raise TimeoutError(f"Timeout: primljeno {len(data)}/{nbytes} bajtova")
        data.extend(chunk)
    return bytes(data)

def show_images(fpga_im: np.ndarray, sw_out: np.ndarray):
    diff = np.abs(sw_out.astype(np.int16) - fpga_im.astype(np.int16)).astype(np.uint8)

    fig, ax = plt.subplots(1, 3, figsize=(12, 4))
    ax[0].imshow(fpga_im, cmap="gray", vmin=0, vmax=255)
    ax[0].set_title("FPGA image")
    ax[0].axis("off")

    ax[1].imshow(sw_out, cmap="gray", vmin=0, vmax=255)
    ax[1].set_title("SW output")
    ax[1].axis("off")

    ax[2].imshow(diff, cmap="gray", vmin=0, vmax=255)
    ax[2].set_title("Abs diff")
    ax[2].axis("off")

    plt.tight_layout()
    plt.show()

def sw_sobel_reference(sw_im: np.ndarray, nfrac: int = 8) -> np.ndarray:
    coeffs_h = np.array([[-1, 0, 1],
                         [-2, 0, 2],
                         [-1, 0, 1]])
    coeffs_v = np.array([[-1, -2, -1],
                         [ 0,  0,  0],
                         [ 1,  2,  1]])

    Gh = correlate2d(sw_im, coeffs_h, mode="valid")
    Gv = correlate2d(sw_im, coeffs_v, mode="valid")

    rows, cols = Gh.shape
    G = np.zeros((rows, cols), dtype=np.uint8)

    for r in range(rows):
        for c in range(cols):
            gsq = int(Gh[r, c]**2 + Gv[r, c]**2)
            gsq = int(gsq // 64)  
            sqrt_val, _ = binary_digit_by_digit_sqrt(gsq, nfrac)
            G[r, c] = np.uint8(np.round(sqrt_val))

    out = sw_im.copy()
    out[1:-1, 1:-1] = G  # valid prozor mapira na centre
    return out

def main():
    IMAGE_SIZE = 256
    N = IMAGE_SIZE * IMAGE_SIZE
    COM_PORT = "COM3"
    BAUD = 115200

    # --- Read from FPGA ---
    with serial.Serial(COM_PORT, BAUD, timeout=8) as ser:
        ser.reset_input_buffer()  # izbaci stare bajtove iz prethodnog run-a

        raw = read_exact(ser, N)
        pixels = struct.unpack(f"<{N}B", raw)
        fpga_im = np.array(pixels, dtype=np.uint8).reshape(IMAGE_SIZE, IMAGE_SIZE)

    print("FPGA image:\n", fpga_im)

    # --- SW reference ---
    # IN_FILE = "input_img_krug_88.txt"
    # sw_im = load_bits(IN_FILE, N).reshape(IMAGE_SIZE, IMAGE_SIZE)
    swIm = plt.imread('cameraman.bmp')
    sw_out = sw_sobel_reference(swIm, nfrac=8)

    show_images(fpga_im, sw_out)

if __name__ == "__main__":
    main()