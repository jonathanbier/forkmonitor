import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Chaintip from 'forkMonitorApp/components/chaintip';


const mockNodes = [
    {id: 1, name: "Bitcoin Core", version: 170100, height: 500000, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, height: 500000, unreachable_since: null, ibd: false}
]

const chaintip = {
    block: {
        hash: "abcd",
        height: 500000,
        timestamp: 1,
        work: 86.000001,
        tx_count: 3024,
        size: 1328797
    },
    nodes: mockNodes
}

describe('rendered component', () => {

  const wrapper = mount(<Chaintip
    key={ chaintip.hash }
    chaintip={ chaintip }
    nodes={ mockNodes }
    index={ 0 }
    last={ true }
  />);

  test('should contain two nodes', () => {
    expect(wrapper.find('.node-info')).toHaveLength(2);
  });

  test('should display transaction count of tip block', () => {
    expect(wrapper.find('.chaintip-info').text()).toContain("3,024");
  });

  test('should display size of tip block', () => {
    expect(wrapper.find('.chaintip-info').text()).toContain("blocksize");
    expect(wrapper.find('.chaintip-info').text()).toContain("1.33 MB");
  });

  test('should handle missing size', () => {
    chaintip.block.size = null;
    wrapper.setProps({chaintip: chaintip});
    expect(wrapper.find('.chaintip-info').text()).not.toContain("blocksize");
  });

});
