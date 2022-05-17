import logging
from os import getenv

logger = logging.getLogger(__name__)

level = getenv("LOG_LEVEL", logging.INFO)
formatter = logging.Formatter(
    "%(asctime)s %(levelname)-8s %(module)-21s %(funcName)-25s: %(message)s"
)
handler = logging.StreamHandler()

handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(level)
