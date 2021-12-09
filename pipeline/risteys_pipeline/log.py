import logging
from os import getenv


level = getenv("LOG_LEVEL", logging.INFO)
logger = logging.getLogger("pipeline")
formatter = logging.Formatter(
    "%(asctime)s %(levelname)-8s %(module)-21s %(funcName)-25s: %(message)s"
)
# handler = logging.StreamHandler()
handler = logging.FileHandler("risteys.log")

handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(level)
