import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import InflationTooltip from 'forkMonitorApp/components/inflationTooltip';

let wrapper;

describe('InflationTooltip', () => {

  const chaintip = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }

  const txOutset = {
    id: 1,
    txouts: 63265720,
    total_amount: "17993054.82194891",
    created_at: "2019-10-15T09:42:54.919Z",
    inflated: false
  };

  const node = {
    id: 1,
    name_with_version: "Bitcoin Core 0.20.0",
    best_block: chaintip,
    unreachable_since: null,
    ibd: false,
    height: 500000,
    os: "Linux"
  };


  beforeAll(() => {
    wrapper = mount(<InflationTooltip
      node={ node }
      txOutset={ txOutset }
    />)
  });

  test('should show coin supply', () => {
    expect(wrapper.text()).toContain("17,993,054.82194891");
  });

  test('should not show coin supply if there is no txoutset', () => {
    wrapper.setProps({txOutset: null});
    expect(wrapper.text()).not.toContain("17,993,054.82194891");
  });

  test('should show block height', () => {
    expect(wrapper.text()).toContain("500,000");
  });

});
