import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Node from 'forkMonitorApp/components/node';

test('rendered component', () => {
  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }
  const node = {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false}

  const wrapper = shallow(<Node
    key={ 0 }
    node={ node }
  />);
  expect(wrapper.find('.node-version')).toHaveLength(1);
});
