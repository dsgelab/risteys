function openDialog(dialogId) {
	const dialogNode = document.getElementById(dialogId);
	dialogNode.classList.remove('hidden');

	// Make underneath content unscrollable, indicating it is inert
	document.body.classList.add('dialog-open');

	dialogNode.addEventListener('click', (e) => {
		e.stopPropagation();  // prevent going upwards to DOM root
		if (e.target === dialogNode) {
			closeDialog(dialogId);
		}
	});

	document.addEventListener('keydown', (e) => {
		if (e.code === 'Escape') {
			closeDialog(dialogId);
		}
	}, {once: true});
}

function closeDialog(dialogId) {
	const dialogNode = document.getElementById(dialogId);
	dialogNode.classList.add('hidden');
	document.body.classList.remove('dialog-open');
}

export {openDialog, closeDialog};
