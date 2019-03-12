import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodesWithoutTip from 'forkMonitorApp/components/nodesWithoutTip';

test('rendered component', () => {
  const nodes = [
    {id: 1, name: "Bitcoin Core", version: 170100, best_block: null, unreachable_since: null, ibd: false},
  ]

  const wrapper = shallow(<NodesWithoutTip
    coin="BTC"
    nodes={ nodes }
  />);
  expect(wrapper.find('.node-info')).toHaveLength(1);
});
