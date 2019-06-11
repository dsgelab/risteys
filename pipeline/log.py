import logging

logger = logging.getLogger("pipeline")

handler = logging.StreamHandler()

formatter = logging.Formatter(
    "%(asctime)s %(levelname)-5s %(module)-21s %(funcName)-25s: %(message)s",
    "%H:%M:%S"
)
handler.setFormatter(formatter)

logger.addHandler(handler)
logger.setLevel(logging.DEBUG)
