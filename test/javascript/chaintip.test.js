import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Chaintip from 'forkMonitorApp/components/chaintip';

test('rendered component', () => {
  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }
  const nodes = [
    {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, best_block: chaintip, unreachable_since: null, ibd: false}
  ]

  const wrapper = shallow(<Chaintip
    key={ chaintip.hash }
    chaintip={ chaintip }
    nodes={ nodes }
    index={ 0 }
    last={ true }
  />);
  expect(wrapper.find('.node-info')).toHaveLength(2);
});

test('can handle node without chaintip', () => {
  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }
  const nodes = [
    {id: 1, name: "Bitcoin Core", version: 170100, best_block: null, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, best_block: chaintip, unreachable_since: null, ibd: false}
  ]

  const wrapper = shallow(<Chaintip
    key={ chaintip.hash }
    chaintip={ chaintip }
    nodes={ nodes }
    index={ 0 }
    last={ true }
  />);
  expect(wrapper.find('.node-info')).toHaveLength(1);
});
