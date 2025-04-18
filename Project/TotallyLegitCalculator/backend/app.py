import src.peer as pr
import src.utils_config as json_utl



if __name__ == '__main__':
    # Execute when the module is not initialized from an import statement.
    json_utl.reset_config()



    peer = pr.Peer_connection()
    peer.start()
