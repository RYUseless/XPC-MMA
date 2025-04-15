import socket
import threading
import time
import sys
import struct
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

"""

ONLY FOR TESTING, WILL IMPLEMENT DISCOVERY, MOVE CRYPTO TO UTILS_CRYPTO ETC, NOW JUST TESTING SOME FUNNY AHH BULLSHIT

"""
HOST = '127.0.0.1'
PORT = 12345
CONNECTION_TIMEOUT = 5  # Seconds before switching to host mode

KEY = b'secretkey1234567'  # 16 bytes for AES-128
IV = b'initialvector123'   # 16 bytes IV (for CBC mode)

def encrypt_payload(data: bytes) -> bytes:
    """
    Encrypts the input data using AES-CBC and prepends the length of the ciphertext.
    """
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    ciphertext = cipher.encrypt(pad(data, AES.block_size))
    length = struct.pack('!I', len(ciphertext))  # 4-byte big-endian length
    return length + ciphertext

def decrypt_payload(sock) -> bytes:
    """
    Receives and decrypts a message from the socket.
    """
    raw_len = sock.recv(4)
    if not raw_len:
        return b''
    payload_len = struct.unpack('!I', raw_len)[0]
    encrypted = b''
    while len(encrypted) < payload_len:
        part = sock.recv(payload_len - len(encrypted))
        if not part:
            break
        encrypted += part
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    return unpad(cipher.decrypt(encrypted), AES.block_size)

def receive(sock):
    """
    Handles receiving and decrypting messages from the socket.
    """
    while True:
        try:
            decrypted_data = decrypt_payload(sock)
            if not decrypted_data:
                print("Remote side has closed the connection.")
                break
            print(f"\033[32mREPLY>> {decrypted_data.decode('utf-8')}\033[0m")
        except Exception as e:
            print(f"Receive error: {e}")
            break
    print("Receive thread terminated.")
    try:
        sock.close()
    except OSError as e:
        print(f"Error closing socket (receive): {e}")

def send(sock):
    """
    Handles input, encryption, and sending of messages through the socket.
    """
    while True:
        message = input()
        try:
            encrypted_packet = encrypt_payload(message.encode('utf-8'))
            sock.sendall(encrypted_packet)
            if message.lower() == 'konec':
                break
        except Exception as e:
            print(f"Send error: {e}")
            break
    print("Send thread terminated.")
    try:
        sock.close()
    except OSError as e:
        print(f"Error closing socket (send): {e}")
    sys.exit(0)

def main():
    try:
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.bind((HOST, PORT))
        server_socket.listen(1)
        print(f"Waiting for connection on {HOST}:{PORT}...")
        client_socket, addr = server_socket.accept()
        print(f"Connected to {addr}")
        receive_thread = threading.Thread(target=receive, args=(client_socket,))
        send_thread = threading.Thread(target=send, args=(client_socket,))
        receive_thread.daemon = True
        send_thread.daemon = True
        receive_thread.start()
        send_thread.start()
        server_socket.close()
        while True:
            time.sleep(1)

    except OSError as e:
        if e.errno == 98:  # id → Address already in use (peer mode)
            try:
                client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                client_socket.connect((HOST, PORT))
                print(f"Connected to server at {HOST}:{PORT}")
                receive_thread = threading.Thread(target=receive, args=(client_socket,))
                send_thread = threading.Thread(target=send, args=(client_socket,))
                receive_thread.daemon = True
                send_thread.daemon = True
                receive_thread.start()
                send_thread.start()
                while True:
                    time.sleep(1)
            except Exception as e:
                print(f"Connection error: {e}")
        else:
            print(f"Socket creation error: {e}")
    except KeyboardInterrupt:
        print("Terminating...")
    finally:
        try:
            if 'client_socket' in locals():
                client_socket.close()
            if 'server_socket' in locals():
                server_socket.close()
        except Exception as e:
            print(f"Error closing sockets in final block: {e}")

def run():
    main()

