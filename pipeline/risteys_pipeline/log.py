import logging
from os import getenv


level = getenv("LOG_LEVEL", logging.INFO)
logger = logging.getLogger("pipeline")
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s %(levelname)-8s %(module)-21s %(funcName)-25s: %(message)s")

handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(level)
