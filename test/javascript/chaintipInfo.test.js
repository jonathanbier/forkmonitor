import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import ChaintipInfo from 'forkMonitorApp/components/chaintipInfo';

const chaintip = {
    block: {
        hash: "abcd",
        height: 500000,
        timestamp: 1,
        work: 86.000001,
        tx_count: 3024,
        size: 1328797
    },
    nodes: null // Unused
}

describe('rendered component', () => {

  const wrapper = mount(<ChaintipInfo
    chaintip={ chaintip }
  />);

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
