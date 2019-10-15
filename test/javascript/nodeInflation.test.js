import React from 'react';
import ReactDOM from 'react-dom';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodeInflation from 'forkMonitorApp/components/nodeInflation';

let wrapper;

describe('NodeBehind', () => {

  const txOutset = {
    txouts: 63265720,
    total_amount: "17993054.82194891",
    created_at: "2019-10-15T09:42:54.919Z",
    inflated: false
  };

  beforeAll(() => {
    wrapper = mount(<NodeInflation
      txOutset={ txOutset }
    />)
  });

  test('should show coin supply', () => {
    expect(wrapper.text()).toContain("17,993,054.8");
  });
  
  test('should show spinner if supply is being calculated', () => {
    wrapper.setProps({txOutset: null})
    expect(wrapper.exists('.fa-spinner')).toEqual(true);
  });
  
  test('should show "inflated" if supply is inflated', () => {
    wrapper.setProps({txOutset: {inflated: true}})
    expect(wrapper.exists('.fa-times-circle')).toEqual(true);
  });

});
