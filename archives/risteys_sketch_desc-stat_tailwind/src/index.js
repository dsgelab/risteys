import _ from 'lodash';
import './style.css';

function component() {
    let element = document.createElement('div');
    element.textContent = _.join(['hey', 'webpa'], ' ');
    element.classList.add('hello');
    return element;
}

document.body.appendChild(component());
