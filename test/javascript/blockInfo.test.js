import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import BlockInfo from 'forkMonitorApp/components/blockInfo';

import MockCableApp from './__mocks__/cableAppMock'

const block = {
  hash: "abcd",
  height: 500000,
  timestamp: 1,
  work: 86.000001,
  tx_count: 3024,
  size: 1328797
}

describe('rendered component', () => {

  const wrapper = mount(<BlockInfo
    block={ block }
    cableApp={ MockCableApp }
  />);

  test('should display transaction count of tip block', () => {
    expect(wrapper.find('.block-info').text()).toContain("3,024");
  });

  test('should display size of tip block', () => {
    expect(wrapper.find('.block-info').text()).toContain("Size");
    expect(wrapper.find('.block-info').text()).toContain("1.33 MB");
  });

  test('should handle missing size', () => {
    block.size = null;
    wrapper.setProps({block: block});
    expect(wrapper.find('.block-info').text()).not.toContain("Size");
  });

});
