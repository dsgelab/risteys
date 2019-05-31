import logging

logger = logging.getLogger("pipeline")

handler = logging.StreamHandler()

formatter = logging.Formatter(
    "%(asctime)s %(name)s %(levelname)-5s %(message)s",
    "%H:%M:%S"
)
handler.setFormatter(formatter)

logger.addHandler(handler)
logger.setLevel(logging.DEBUG)
